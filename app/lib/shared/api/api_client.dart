import 'package:dio/dio.dart';

import 'models.dart';

/// 오운 백엔드 API 베이스 URL.
///
/// - iOS 시뮬레이터: 호스트와 네트워크를 공유하므로 localhost 사용.
/// - Android 에뮬레이터: `--dart-define=OUN_API_BASE_URL=http://10.0.2.2:3000`
/// - 실기기: 개발 PC의 LAN IP 지정.
const String kApiBaseUrl = String.fromEnvironment(
  'OUN_API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

/// 오운 API 클라이언트. 액세스 토큰을 메모리에 보관하고 요청에 자동 첨부하며,
/// 401이면 저장된 닉네임으로 dev 재로그인 후 한 번 재시도한다.
/// (카카오 로그인 연동 전까지의 dev 인증 흐름)
class ApiClient {
  ApiClient() : _dio = Dio(BaseOptions(baseUrl: kApiBaseUrl)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // 토큰 만료 → 재로그인 후 1회 재시도
          if (e.response?.statusCode == 401 && _nickname != null && !_retrying) {
            try {
              _retrying = true;
              await devLogin(_nickname!);
              final res = await _dio.fetch<dynamic>(
                e.requestOptions..headers['Authorization'] = 'Bearer $_accessToken',
              );
              return handler.resolve(res);
            } catch (_) {
              // 재로그인 실패 → 원래 에러 유지
            } finally {
              _retrying = false;
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  final Dio _dio;
  String? _accessToken;
  String? _nickname;
  bool _retrying = false;

  bool get hasSession => _accessToken != null;

  void clearSession() {
    _accessToken = null;
    _nickname = null;
  }

  // ── 인증 ──────────────────────────────────────────────

  /// 개발용 로그인/회원가입. 닉네임만으로 세션을 만든다(없으면 생성).
  Future<Profile> devLogin(String nickname, {String? gender}) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/dev', data: {
      'nickname': nickname,
      'gender': ?gender,
    });
    _accessToken = res.data!['accessToken'] as String;
    _nickname = nickname;
    return me();
  }

  // ── 프로필/지갑 ────────────────────────────────────────

  Future<Profile> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return Profile.fromJson(res.data!);
  }

  Future<int> wallet() async {
    final res = await _dio.get<Map<String, dynamic>>('/wallet');
    return res.data!['balance'] as int;
  }

  // ── 운동 ──────────────────────────────────────────────

  Future<WorkoutResult> createWorkout({
    required String sport,
    required int durationSec,
    int? distanceM,
    int? steps,
    String? bodyPart,
    int? sets,
    bool hasPhoto = false,
    String? message,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/workouts', data: {
      'sport': sport,
      'durationSec': durationSec,
      'distanceM': ?distanceM,
      'steps': ?steps,
      'bodyPart': ?bodyPart,
      'sets': ?sets,
      'hasPhoto': hasPhoto,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    final d = res.data!;
    return WorkoutResult(
      verified: d['verified'] as bool? ?? false,
      reward: d['reward'] as int? ?? 0,
      balance: d['balance'] as int? ?? 0,
    );
  }

  Future<List<Workout>> workouts({DateTime? from, DateTime? to}) async {
    final res = await _dio.get<Map<String, dynamic>>('/workouts', queryParameters: {
      'from': ?from?.toUtc().toIso8601String(),
      'to': ?to?.toUtc().toIso8601String(),
    });
    return (res.data!['items'] as List)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CalendarDay>> calendar(String month) async {
    final res = await _dio
        .get<Map<String, dynamic>>('/workouts/calendar', queryParameters: {'month': month});
    return (res.data!['days'] as List)
        .map((e) => CalendarDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MonthSummary> monthSummary(String month) async {
    final res = await _dio
        .get<Map<String, dynamic>>('/workouts/summary', queryParameters: {'month': month});
    return MonthSummary.fromJson(res.data!);
  }

  // ── 퀘스트/업적 ────────────────────────────────────────

  Future<QuestBoard> quests() async {
    final res = await _dio.get<Map<String, dynamic>>('/quests');
    return QuestBoard.fromJson(res.data!);
  }

  Future<ClaimResult> claimQuest(String key) async {
    final res = await _dio.post<Map<String, dynamic>>('/quests/$key/claim');
    return ClaimResult(
      reward: res.data!['reward'] as int,
      balance: res.data!['balance'] as int,
    );
  }

  Future<(int earned, int total, List<Achievement>)> achievements() async {
    final res = await _dio.get<Map<String, dynamic>>('/achievements');
    final items = (res.data!['items'] as List)
        .map((e) => Achievement.fromJson(e as Map<String, dynamic>))
        .toList();
    return (res.data!['earned'] as int, res.data!['total'] as int, items);
  }

  // ── 상점 ──────────────────────────────────────────────

  Future<List<ShopItem>> shopItems({String? category}) async {
    final res = await _dio.get<Map<String, dynamic>>('/shop/items', queryParameters: {
      'category': ?category,
    });
    return (res.data!['items'] as List)
        .map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 구매 → 차감 후 잔액 반환.
  Future<int> orderItem(String itemKey) async {
    final res = await _dio.post<Map<String, dynamic>>('/shop/orders', data: {'itemKey': itemKey});
    return res.data!['balance'] as int;
  }

  Future<void> equipItem(String itemKey) async {
    await _dio.put<Map<String, dynamic>>('/character/equip', data: {'itemKey': itemKey});
  }

  // ── 소셜: 친구/응원 ────────────────────────────────────

  Future<List<Friend>> friends() async {
    final res = await _dio.get<Map<String, dynamic>>('/friends');
    return (res.data!['items'] as List)
        .map((e) => Friend.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// @nickname 친구 추가 → 추가된 친구의 표시 이름 반환.
  Future<String> addFriend(String nickname) async {
    final res = await _dio.post<Map<String, dynamic>>('/friends', data: {'nickname': nickname});
    return res.data!['displayName'] as String;
  }

  Future<FriendHome> friendHome(String nickname) async {
    final res = await _dio.get<Map<String, dynamic>>('/users/$nickname/home');
    return FriendHome.fromJson(res.data!);
  }

  Future<void> cheer(String nickname, {String? emoji}) async {
    await _dio.post<Map<String, dynamic>>('/users/$nickname/cheer', data: {'emoji': ?emoji});
  }

  // ── 크루 ──────────────────────────────────────────────

  Future<CrewDetail> createCrew(String name, int weeklyGoal) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/crews', data: {'name': name, 'weeklyGoal': weeklyGoal});
    return CrewDetail.fromJson(res.data!);
  }

  Future<List<CrewCardData>> myCrews() async {
    final res = await _dio.get<Map<String, dynamic>>('/crews');
    return (res.data!['items'] as List)
        .map((e) => CrewCardData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CrewDetail> crewDetail(String crewId) async {
    final res = await _dio.get<Map<String, dynamic>>('/crews/$crewId');
    return CrewDetail.fromJson(res.data!);
  }

  Future<String> inviteToCrew(String crewId, String nickname) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/crews/$crewId/members', data: {'nickname': nickname});
    return res.data!['displayName'] as String;
  }

  Future<void> leaveCrew(String crewId) async {
    await _dio.delete<Map<String, dynamic>>('/crews/$crewId/members/me');
  }

  Future<List<CrewPostData>> crewFeed(String crewId) async {
    final res = await _dio.get<Map<String, dynamic>>('/crews/$crewId/feed');
    return (res.data!['items'] as List)
        .map((e) => CrewPostData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CrewCommentData> commentOnPost(String postId, String text) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/crews/posts/$postId/comments', data: {'text': text});
    return CrewCommentData.fromJson(res.data!);
  }

  /// 응원 토글 → (cheered, cheers).
  Future<(bool, int)> togglePostCheer(String postId) async {
    final res = await _dio.post<Map<String, dynamic>>('/crews/posts/$postId/cheer');
    return (res.data!['cheered'] as bool, res.data!['cheers'] as int);
  }

  Future<List<CrewReward>> crewRewards(String crewId) async {
    final res = await _dio.get<Map<String, dynamic>>('/crews/$crewId/rewards');
    return (res.data!['items'] as List)
        .map((e) => CrewReward.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 레벨 보상 수령 → (coins, balance).
  Future<(int, int)> claimCrewReward(String crewId, int level) async {
    final res = await _dio.post<Map<String, dynamic>>('/crews/$crewId/rewards/$level/claim');
    return (res.data!['coins'] as int, res.data!['balance'] as int);
  }
}
