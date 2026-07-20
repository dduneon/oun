import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

/// 앱 전역 API 클라이언트.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// ─────────────────────────────────────────────────────────────
// 인증 상태
// ─────────────────────────────────────────────────────────────

/// 로그인 상태. restoring: 저장된 세션 복원 중(스플래시).
enum AuthStatus { restoring, loggedOut, loggedIn }

class AuthState {
  const AuthState(this.status, {this.profile, this.error});
  final AuthStatus status;
  final Profile? profile;
  final String? error;
}

/// 세션 관리: 닉네임을 로컬에 저장해 두고 앱 시작 시 dev 로그인으로 복원한다.
/// (카카오 로그인 연동 시 이 컨트롤러의 login만 교체하면 된다)
class AuthController extends Notifier<AuthState> {
  static const _prefsKey = 'oun_nickname';

  @override
  AuthState build() {
    _restore();
    return const AuthState(AuthStatus.restoring);
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString(_prefsKey);
    if (nickname == null) {
      state = const AuthState(AuthStatus.loggedOut);
      return;
    }
    try {
      final profile = await ref.read(apiClientProvider).devLogin(nickname);
      state = AuthState(AuthStatus.loggedIn, profile: profile);
    } catch (_) {
      // 서버 연결 실패 → 로그인 화면에서 다시 시도
      state = const AuthState(AuthStatus.loggedOut, error: '서버에 연결할 수 없어요');
    }
  }

  /// 로그인/회원가입(dev). 성공 시 닉네임을 저장해 다음 실행에 복원.
  Future<bool> login(String nickname, {String? gender}) async {
    try {
      final profile =
          await ref.read(apiClientProvider).devLogin(nickname, gender: gender);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, nickname);
      state = AuthState(AuthStatus.loggedIn, profile: profile);
      return true;
    } catch (_) {
      state = const AuthState(AuthStatus.loggedOut, error: '로그인에 실패했어요. 서버 연결을 확인해 주세요');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    ref.read(apiClientProvider).clearSession();
    state = const AuthState(AuthStatus.loggedOut);
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

// ─────────────────────────────────────────────────────────────
// 도메인 데이터 프로바이더 (서버가 source of truth)
// ─────────────────────────────────────────────────────────────

/// 로그인 상태가 아니면 데이터 요청을 보류시키는 가드.
Future<ApiClient> _authed(Ref ref) async {
  final auth = ref.watch(authProvider);
  if (auth.status != AuthStatus.loggedIn) {
    throw StateError('로그인이 필요해요');
  }
  return ref.watch(apiClientProvider);
}

final profileProvider = FutureProvider<Profile>((ref) async {
  final api = await _authed(ref);
  return api.me();
});

final walletProvider = FutureProvider<int>((ref) async {
  final api = await _authed(ref);
  return api.wallet();
});

/// 오늘(로컬 자정 이후) 운동 분 합계 — 홈 카드.
final todayMinutesProvider = FutureProvider<int>((ref) async {
  final api = await _authed(ref);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final items = await api.workouts(from: start);
  return items.fold<int>(0, (s, w) => s + w.minutes);
});

/// 최근 운동 기록 — 기록 탭.
final recentWorkoutsProvider = FutureProvider<List<Workout>>((ref) async {
  final api = await _authed(ref);
  return api.workouts();
});

/// 월별 캘린더(도트). family 인자: 'YYYY-MM'.
final calendarProvider =
    FutureProvider.family<List<CalendarDay>, String>((ref, month) async {
  final api = await _authed(ref);
  return api.calendar(month);
});

/// 월 요약. family 인자: 'YYYY-MM'.
final monthSummaryProvider =
    FutureProvider.family<MonthSummary, String>((ref, month) async {
  final api = await _authed(ref);
  return api.monthSummary(month);
});

final questsProvider = FutureProvider<QuestBoard>((ref) async {
  final api = await _authed(ref);
  return api.quests();
});

final achievementsProvider =
    FutureProvider<(int, int, List<Achievement>)>((ref) async {
  final api = await _authed(ref);
  return api.achievements();
});

/// 상점 아이템. family 인자: 카테고리(clothing/hair/prop/furniture).
final shopItemsProvider =
    FutureProvider.family<List<ShopItem>, String>((ref, category) async {
  final api = await _authed(ref);
  return api.shopItems(category: category);
});

final friendsProvider = FutureProvider<List<Friend>>((ref) async {
  final api = await _authed(ref);
  return api.friends();
});

final friendHomeProvider =
    FutureProvider.family<FriendHome, String>((ref, nickname) async {
  final api = await _authed(ref);
  return api.friendHome(nickname);
});

final crewsProvider = FutureProvider<List<CrewCardData>>((ref) async {
  final api = await _authed(ref);
  return api.myCrews();
});

final crewDetailProvider =
    FutureProvider.family<CrewDetail, String>((ref, crewId) async {
  final api = await _authed(ref);
  return api.crewDetail(crewId);
});

final crewFeedProvider =
    FutureProvider.family<List<CrewPostData>, String>((ref, crewId) async {
  final api = await _authed(ref);
  return api.crewFeed(crewId);
});

final crewRewardsProvider =
    FutureProvider.family<List<CrewReward>, String>((ref, crewId) async {
  final api = await _authed(ref);
  return api.crewRewards(crewId);
});

/// 운동 기록 저장 후 영향을 받는 데이터 일괄 갱신.
void invalidateAfterWorkout(WidgetRef ref) {
  ref.invalidate(walletProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(todayMinutesProvider);
  ref.invalidate(recentWorkoutsProvider);
  ref.invalidate(calendarProvider);
  ref.invalidate(monthSummaryProvider);
  ref.invalidate(questsProvider);
  ref.invalidate(achievementsProvider);
  ref.invalidate(crewsProvider);
  ref.invalidate(crewFeedProvider);
  ref.invalidate(crewDetailProvider);
}
