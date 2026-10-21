import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/social_sign_in.dart';
import '../push/push_messaging.dart';
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
  const AuthState(
    this.status, {
    this.profile,
    this.error,
    this.needsOnboarding = false,
  });
  final AuthStatus status;
  final Profile? profile;
  final String? error;

  /// 소셜 로그인으로 방금 가입 — 캐릭터·닉네임 고르기를 먼저 보여 준다.
  final bool needsOnboarding;
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

  /// 카카오로 시작하기. 취소하면 아무 일도 없다(false).
  Future<bool> signInWithKakao() async {
    try {
      final token = await kakaoAccessToken();
      if (token == null) return false;
      return _runSocial(() => ref.read(apiClientProvider).kakaoLogin(token));
    } catch (e) {
      // 카카오 SDK 오류(콘솔 설정·키 해시 등)는 원인이 메시지에만 있다.
      debugPrint('[kakao] 로그인 실패: $e');
      state = AuthState(AuthStatus.loggedOut,
          error: _errorMessage(
              e,
              kDebugMode
                  ? '카카오 로그인에 실패했어요\n$e'
                  : '카카오 로그인에 실패했어요'));
      return false;
    }
  }

  /// Apple로 계속하기. 취소하면 아무 일도 없다(false).
  Future<bool> signInWithApple() async {
    try {
      final c = await appleCredential();
      if (c == null) return false;
      return _runSocial(() => ref
          .read(apiClientProvider)
          .appleLogin(c.identityToken, name: c.name));
    } catch (e) {
      debugPrint('[apple] 로그인 실패: $e');
      state = AuthState(AuthStatus.loggedOut,
          error: _errorMessage(e, 'Apple 로그인에 실패했어요'));
      return false;
    }
  }

  Future<bool> _runSocial(Future<(Profile, bool)> Function() call) {
    var isNew = false;
    return _run(() async {
      final (profile, created) = await call();
      isNew = created;
      return profile;
    }, onboarding: () => isNew);
  }

  /// 첫 가입 화면에서 캐릭터·닉네임을 정하고 나면 홈으로.
  void completeOnboarding(Profile profile) {
    state = AuthState(AuthStatus.loggedIn, profile: profile);
  }

  /// 인증 공통 처리. 성공 시 발급된 refresh 토큰을 저장해 다음 실행에 복원.
  Future<bool> _run(
    Future<Profile> Function() authCall, {
    bool Function()? onboarding,
  }) async {
    try {
      final profile = await authCall();
      final rt = ref.read(apiClientProvider).refreshToken;
      if (rt != null) await _secureStorage.write(key: _prefsKey, value: rt);
      state = AuthState(
        AuthStatus.loggedIn,
        profile: profile,
        needsOnboarding: onboarding?.call() ?? false,
      );
      return true;
    } catch (e) {
      state = AuthState(
        AuthStatus.loggedOut,
        error: _errorMessage(e, '서버에 연결할 수 없어요. 잠시 후 다시 시도해 주세요'),
      );
      return false;
    }
  }

  /// 이름·닉네임을 바꾼 뒤 세션의 프로필도 갈아 끼운다.
  void updateProfile(Profile profile) {
    if (state.status != AuthStatus.loggedIn) return;
    state = AuthState(AuthStatus.loggedIn, profile: profile);
  }

  Future<void> logout() async {
    // 푸시 해제는 인증이 필요하니 세션을 지우기 전에 한다.
    await ref.read(pushMessagingProvider).stop();
    await _secureStorage.delete(key: _prefsKey);
    ref.read(apiClientProvider).clearSession();
    state = const AuthState(AuthStatus.loggedOut);
  }
}

/// 서버(NestJS)가 내려주는 에러 메시지를 뽑아낸다. 없으면 fallback.
///
/// 응원 쿨다운·하루 상한처럼 **사용자가 알아야 할 이유**를 서버가 문장으로
/// 내려주므로, 화면에서 뭉뚱그리지 말고 이걸 그대로 보여준다.
String apiErrorMessage(Object e, String fallback) =>
    _errorMessage(e, fallback);

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

/// 코인 내역. 화면을 열 때마다 새로 받는다(autoDispose).
final coinHistoryProvider =
    FutureProvider.autoDispose<CoinHistory>((ref) async {
  final api = await _authed(ref);
  return api.coinHistory();
});

/// 홈 캐릭터의 기분(표정·말풍선).
final characterMoodProvider = FutureProvider<CharacterMoodState>((ref) async {
  final api = await _authed(ref);
  return api.characterMood();
});

/// 월말 리포트(YYYY-MM).
final monthlyReportProvider =
    FutureProvider.family<MonthlyReport, String>((ref, month) async {
  final api = await _authed(ref);
  return api.monthlyReport(month);
});

/// 분류별 푸시 수신 설정.
final notificationSettingsProvider =
    FutureProvider<NotificationSettings>((ref) async {
  final api = await _authed(ref);
  return api.notificationSettings();
});

/// 휴식일·기록 보호권 상태.
final careProvider = FutureProvider<CareStatus>((ref) async {
  final api = await _authed(ref);
  return api.care();
});

/// 휴식일 선언·보호권 사용으로 바뀌는 데이터.
final careProviders = <RefreshTarget>[
  careProvider,
  characterMoodProvider,
  profileProvider,
  walletProvider,
];

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

/// 상점 아이템. family 인자: 카테고리(clothing/bottom/shoes/hair/prop).
final shopItemsProvider =
    FutureProvider.family<List<ShopItem>, String>((ref, category) async {
  final api = await _authed(ref);
  return api.shopItems(category: category);
});

/// 내 장착 상태(슬롯 → 아이템 + 특수 효과). 장착을 바꾸면 이걸 무효화한다.
final loadoutProvider = FutureProvider<Loadout>((ref) async {
  final api = await _authed(ref);
  return api.loadout();
});

/// 슬롯별 장착 아이템. 홈 캐릭터와 상점의 장착 표시가 함께 구독한다.
final equippedItemsProvider = FutureProvider<Map<String, String>>(
  (ref) async => (await ref.watch(loadoutProvider.future)).equipment,
);

/// 장착 중인 특수 효과 아이템 키(희귀 아이템 반짝임 등).
final specialFxProvider = FutureProvider<Set<String>>(
  (ref) async => (await ref.watch(loadoutProvider.future)).specialFx,
);

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

/// 친구 찾기 검색 결과(입력이 바뀔 때마다 새 키). 화면을 떠나면 버린다.
final userSearchProvider = FutureProvider.autoDispose
    .family<List<PersonCard>, String>((ref, query) async {
  final api = await _authed(ref);
  return api.searchUsers(query);
});

/// 친구 찾기에서 연 프로필.
final userProfileProvider = FutureProvider.autoDispose
    .family<PersonCard, String>((ref, nickname) async {
  final api = await _authed(ref);
  return api.userProfile(nickname);
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

/// 내가 가입 신청하고 방장 승인을 기다리는 크루.
final myCrewJoinRequestsProvider =
    FutureProvider<List<CrewCardData>>((ref) async {
  final api = await _authed(ref);
  return api.myCrewJoinRequests();
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
  ref.invalidate(characterMoodProvider);
  ref.invalidate(careProvider);
  ref.invalidate(todayMinutesProvider);
  ref.invalidate(recentWorkoutsProvider);
  ref.invalidate(calendarProvider);
  ref.invalidate(monthSummaryProvider);
  ref.invalidate(monthlyReportProvider);
  ref.invalidate(questsProvider);
  ref.invalidate(achievementsProvider);
  ref.invalidate(crewsProvider);
  ref.invalidate(crewFeedProvider);
  ref.invalidate(crewDetailProvider);
}

// ─────────────────────────────────────────────────────────────
// 갱신 묶음
//
// 화면들은 IndexedStack으로 계속 살아 있어서, FutureProvider가 한 번 읽은
// 값을 스스로 다시 읽는 일이 없다. 그래서 "밖에서 벌어진 일"(다른 사람이 보낸
// 친구 요청·크루 초대 등)은 아래 묶음으로 명시적으로 다시 읽어 준다.
// ─────────────────────────────────────────────────────────────

/// 무효화 대상 목록의 원소 타입.
///
/// riverpod 3은 `ProviderOrFamily`를 공개 API로 내보내지 않아 목록에 정적
/// 타입을 줄 수 없다. 실제 무효화는 [invalidateAll]이 한곳에서 처리한다.
typedef RefreshTarget = Object;

/// 묶음 무효화. 같은 프로바이더가 겹쳐 들어와도 한 번만 처리한다.
///
/// [ref]는 `WidgetRef`(화면) 또는 `Ref`(프로바이더/서비스) 둘 다 받는다 —
/// 두 타입이 공통 상위 타입을 갖지 않아 여기서만 동적으로 호출한다.
void invalidateAll(Object ref, List<RefreshTarget> providers) {
  final dynamic r = ref;
  for (final p in providers.toSet()) {
    r.invalidate(p);
  }
}

/// 알림함/뱃지.
final inboxProviders = <RefreshTarget>[
  unreadNotificationsProvider,
  notificationsProvider,
  receivedCheersProvider,
];

/// 소셜 탭(친구/크루)에서 남이 만들어 내는 목록들.
final socialProviders = <RefreshTarget>[
  friendsProvider,
  friendRequestsProvider,
  crewsProvider,
  crewInvitationsProvider,
  crewJoinRequestsProvider,
  myCrewJoinRequestsProvider,
];

/// 하단 탭 순서. 갱신 묶음을 탭 번호로 고르므로 한곳에 이름을 둔다.
abstract final class OunTab {
  static const home = 0;
  static const record = 1;
  static const shop = 2;
  static const social = 3;
  static const my = 4;
}

/// 탭별로 화면에 보이는 데이터. 탭을 다시 열 때 이만큼 다시 읽는다.
List<RefreshTarget> providersForTab(int index) => switch (index) {
      0 => [
          profileProvider,
          characterMoodProvider,
          careProvider,
          loadoutProvider,
          walletProvider,
          todayMinutesProvider,
          questsProvider,
          receivedCheersProvider,
          unreadNotificationsProvider,
        ],
      1 => [
          recentWorkoutsProvider,
          todayMinutesProvider,
          calendarProvider,
          monthSummaryProvider,
          profileProvider,
        ],
      2 => [
          walletProvider,
          shopItemsProvider,
          loadoutProvider,
          profileProvider,
        ],
      3 => socialProviders,
      4 => [
          profileProvider,
          careProvider,
          walletProvider,
          achievementsProvider,
          unreadNotificationsProvider,
        ],
      _ => [],
    };

/// 푸시/인앱 알림 한 건이 바꿔 놓는 데이터.
///
/// 알림함 수치만 갱신하면 "알림은 왔는데 목록엔 없는" 상태가 된다 —
/// 알림이 가리키는 목록(받은 친구 요청·받은 초대 등)도 같이 다시 읽는다.
List<RefreshTarget> providersForNotification(String? type) => switch (type) {
      'friend_request' => [friendRequestsProvider],
      'friend_accepted' => [
          friendsProvider,
          friendRequestsProvider,
          questsProvider,
        ],
      'cheer' => [receivedCheersProvider],
      'streak_protected' => careProviders,
      'crew_invite' => [crewInvitationsProvider],
      'crew_join_request' => [crewJoinRequestsProvider],
      'crew_join_result' => [
          crewsProvider,
          myCrewJoinRequestsProvider,
          crewInvitationsProvider,
          crewJoinRequestsProvider,
        ],
      'crew_comment' || 'crew_post_cheer' => [
          crewFeedProvider,
          crewDetailProvider,
        ],
      // 모르는 종류(서버가 늘렸을 수 있다) → 소셜 목록을 통째로 다시 읽는다.
      _ => socialProviders,
    };

/// 당겨서 새로고침. 그 탭 데이터를 다시 읽고, **다 읽을 때까지 기다린다**
/// (인디케이터가 곧바로 사라지면 갱신된 느낌이 안 난다).
Future<void> refreshTab(WidgetRef ref, int index) async {
  invalidateAll(ref, providersForTab(index));
  final waits = <Future<Object?>>[
    ...switch (index) {
      OunTab.home => [
          ref.read(profileProvider.future),
          ref.read(questsProvider.future),
          ref.read(receivedCheersProvider.future),
        ],
      OunTab.record => [ref.read(recentWorkoutsProvider.future)],
      OunTab.shop => [ref.read(walletProvider.future)],
      OunTab.social => [
          ref.read(friendsProvider.future),
          ref.read(friendRequestsProvider.future),
          ref.read(crewsProvider.future),
          ref.read(crewInvitationsProvider.future),
        ],
      OunTab.my => [
          ref.read(profileProvider.future),
          ref.read(achievementsProvider.future),
        ],
      _ => <Future<Object?>>[],
    },
  ];
  try {
    await Future.wait(waits);
  } catch (_) {
    // 실패는 각 화면의 에러 표시가 알려 준다 — 인디케이터만 닫는다.
  }
}
