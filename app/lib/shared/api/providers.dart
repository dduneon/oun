import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'models.dart';

/// refresh 토큰 보관소. iOS는 Keychain, Android는 EncryptedSharedPreferences.
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

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

/// 세션 관리: refresh 토큰을 로컬에 저장해 두고 앱 시작 시 자동 복원한다.
/// (카카오 로그인 연동 시에도 같은 refresh 토큰 흐름을 재사용한다)
class AuthController extends Notifier<AuthState> {
  static const _prefsKey = 'oun_refresh_token';

  @override
  AuthState build() {
    _restore();
    return const AuthState(AuthStatus.restoring);
  }

  Future<void> _restore() async {
    try {
      final refreshToken = await _secureStorage.read(key: _prefsKey);
      if (refreshToken == null) {
        state = const AuthState(AuthStatus.loggedOut);
        return;
      }
      final profile = await ref.read(apiClientProvider).restore(refreshToken);
      state = AuthState(AuthStatus.loggedIn, profile: profile);
    } catch (_) {
      // 저장소 접근 실패/refresh 만료/서버 연결 실패 → 로그인 화면으로.
      // (스플래시에서 멈추지 않도록 어떤 예외든 여기서 흡수한다)
      try {
        await _secureStorage.delete(key: _prefsKey);
      } catch (_) {}
      state = const AuthState(AuthStatus.loggedOut);
    }
  }

  /// 회원가입: 아이디 + 비밀번호 + 닉네임 + 캐릭터(성별).
  Future<bool> signUp({
    required String username,
    required String password,
    required String nickname,
    required String gender,
  }) async {
    return _run(() => ref.read(apiClientProvider).register(
          username: username,
          password: password,
          nickname: nickname,
          gender: gender,
        ));
  }

  /// 로그인: 아이디 + 비밀번호.
  Future<bool> logIn(String username, String password) {
    return _run(() => ref.read(apiClientProvider).login(username, password));
  }

  /// 인증 공통 처리. 성공 시 발급된 refresh 토큰을 저장해 다음 실행에 복원.
  Future<bool> _run(Future<Profile> Function() authCall) async {
    try {
      final profile = await authCall();
      final rt = ref.read(apiClientProvider).refreshToken;
      if (rt != null) await _secureStorage.write(key: _prefsKey, value: rt);
      state = AuthState(AuthStatus.loggedIn, profile: profile);
      return true;
    } catch (e) {
      state = AuthState(
        AuthStatus.loggedOut,
        error: _errorMessage(e, '서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요'),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _prefsKey);
    ref.read(apiClientProvider).clearSession();
    state = const AuthState(AuthStatus.loggedOut);
  }
}

/// 서버(NestJS)가 내려주는 에러 메시지를 뽑아낸다. 없으면 fallback.
String _errorMessage(Object e, String fallback) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
    }
  }
  return fallback;
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

/// 내가 받은 친구 요청 목록.
final friendRequestsProvider =
    FutureProvider<List<FriendRequestItem>>((ref) async {
  final api = await _authed(ref);
  return api.friendRequests();
});

final friendHomeProvider =
    FutureProvider.family<FriendHome, String>((ref, nickname) async {
  final api = await _authed(ref);
  return api.friendHome(nickname);
});

/// 소셜 탭에서 열릴 세그먼트(0 친구 / 1 크루).
///
/// 소셜 탭은 IndexedStack으로 살아있어서 `go('/crew')`만으로는 이미 열려 있던
/// 세그먼트가 그대로 남는다. 알림을 탭해 "받은 친구 요청"·"받은 초대"로
/// 보내려면 바깥에서 세그먼트를 지정할 수 있어야 한다.
class SocialSegmentController extends Notifier<int> {
  @override
  int build() => 0;

  void show(int segment) => state = segment;
}

final socialSegmentProvider =
    NotifierProvider<SocialSegmentController, int>(SocialSegmentController.new);

/// 내가 받은 응원. `unseen > 0`이면 홈 캐릭터가 반응한다.
final receivedCheersProvider = FutureProvider<ReceivedCheers>((ref) async {
  final api = await _authed(ref);
  return api.receivedCheers();
});

/// 인앱 알림함.
final notificationsProvider = FutureProvider<NotificationBoard>((ref) async {
  final api = await _authed(ref);
  return api.notifications();
});

/// 탭 뱃지용 안 읽은 알림 수(목록 없이 가볍게).
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final api = await _authed(ref);
  return api.unreadNotificationCount();
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

/// 공개 크루 탐방(이름 검색어별). 빈 문자열이면 전체.
final crewDiscoverProvider =
    FutureProvider.family<List<CrewSummary>, String>((ref, q) async {
  final api = await _authed(ref);
  return api.discoverCrews(q: q);
});

/// 내가 받은 크루 초대 목록.
final crewInvitationsProvider =
    FutureProvider<List<CrewInvitation>>((ref) async {
  final api = await _authed(ref);
  return api.myCrewInvitations();
});

/// 방장이 보는 대기중 가입 신청 목록.
final crewJoinRequestsProvider =
    FutureProvider.family<List<CrewJoinRequestItem>, String>((ref, crewId) async {
  final api = await _authed(ref);
  return api.crewJoinRequests(crewId);
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
