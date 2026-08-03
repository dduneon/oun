import 'package:dio/dio.dart';

import 'models.dart';

/// 오운 백엔드 API 베이스 URL.
///
/// - iOS 시뮬레이터: 호스트와 네트워크를 공유하므로 localhost 사용.
/// - Android 에뮬레이터: `--dart-define=OUN_API_BASE_URL=http://10.0.2.2:3000`
/// - 실기기: 개발 PC의 LAN IP 지정.
/// - 배포 서버: `--dart-define=OUN_API_BASE_URL=https://oun-api.dduneon.com`
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
          // 액세스 토큰 만료 → refresh로 재발급 후 1회 재시도
          if (e.response?.statusCode == 401 &&
              _refreshToken != null &&
              !_retrying) {
            try {
              _retrying = true;
              await _refresh();
              final res = await _dio.fetch<dynamic>(
                e.requestOptions..headers['Authorization'] = 'Bearer $_accessToken',
              );
              return handler.resolve(res);
            } catch (_) {
              // refresh 실패 → 원래 에러 유지
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
  String? _refreshToken;
  bool _retrying = false;

  bool get hasSession => _accessToken != null;
  String? get refreshToken => _refreshToken;

  void clearSession() {
    _accessToken = null;
    _refreshToken = null;
  }

  // ── 인증 ──────────────────────────────────────────────

  /// 회원가입: 아이디·비밀번호·닉네임·캐릭터로 계정을 만든다.
  Future<Profile> register({
    required String username,
    required String password,
    required String nickname,
    required String gender,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/register', data: {
      'username': username,
      'password': password,
      'nickname': nickname,
      'gender': gender,
    });
    _setTokens(res.data!);
    return me();
  }

  /// 로그인: 아이디 + 비밀번호.
  Future<Profile> login(String username, String password) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/login', data: {
      'username': username,
      'password': password,
    });
    _setTokens(res.data!);
    return me();
  }

  /// 저장해 둔 refresh 토큰으로 세션 복원(앱 재실행 시).
  Future<Profile> restore(String refreshToken) async {
    _refreshToken = refreshToken;
    await _refresh();
    return me();
  }

  /// refresh 토큰으로 액세스 토큰(및 refresh 토큰) 재발급.
  Future<void> _refresh() async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/refresh',
        data: {'refreshToken': _refreshToken});
    _setTokens(res.data!);
  }

  void _setTokens(Map<String, dynamic> data) {
    _accessToken = data['accessToken'] as String?;
    final rt = data['refreshToken'] as String?;
    if (rt != null) _refreshToken = rt;
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

  /// 운동 사진을 MinIO에 올린다. 서버에서 presigned URL을 받아 직접 PUT하고,
  /// 저장된 오브젝트 키(photoRef)를 돌려준다.
  Future<String> uploadWorkoutPhoto(
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final presign = await _dio.post<Map<String, dynamic>>(
        '/uploads/workout-photo',
        data: {'contentType': contentType});
    final key = presign.data!['key'] as String;
    final uploadUrl = presign.data!['uploadUrl'] as String;
    // presigned URL은 MinIO 절대주소 → 인증 인터셉터/baseUrl 없는 순정 Dio로 PUT.
    await Dio().put<void>(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          Headers.contentTypeHeader: contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
    return key;
  }

  Future<WorkoutResult> createWorkout({
    required String sport,
    required int durationSec,
    int? distanceM,
    int? steps,
    String? bodyPart,
    int? sets,
    String? photoRef,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/workouts', data: {
      'sport': sport,
      'durationSec': durationSec,
      'distanceM': ?distanceM,
      'steps': ?steps,
      'bodyPart': ?bodyPart,
      'sets': ?sets,
      'photoRef': ?photoRef,
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

  /// @nickname에게 친구 요청. 상대가 이미 나를 요청했다면 바로 친구가 된다.
  /// 반환: (status, displayName) — status는 'requested' | 'accepted'.
  Future<(String, String)> sendFriendRequest(String nickname) async {
    final res = await _dio.post<Map<String, dynamic>>('/friends/requests',
        data: {'nickname': nickname});
    return (
      res.data!['status'] as String,
      res.data!['displayName'] as String,
    );
  }

  /// 내가 받은 대기중 친구 요청 목록.
  Future<List<FriendRequestItem>> friendRequests() async {
    final res = await _dio.get<Map<String, dynamic>>('/friends/requests');
    return (res.data!['items'] as List)
        .map((e) => FriendRequestItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 받은 친구 요청 수락/거절.
  Future<void> respondFriendRequest(String requestId, bool accept) async {
    final action = accept ? 'accept' : 'reject';
    await _dio
        .post<Map<String, dynamic>>('/friends/requests/$requestId/$action');
  }

  Future<FriendHome> friendHome(String nickname) async {
    final res = await _dio.get<Map<String, dynamic>>('/users/$nickname/home');
    return FriendHome.fromJson(res.data!);
  }

  Future<void> cheer(String nickname, {String? emoji}) async {
    await _dio.post<Map<String, dynamic>>('/users/$nickname/cheer', data: {'emoji': ?emoji});
  }

  /// 내가 받은 응원. 조회만으로는 확인 처리되지 않는다([markCheersSeen] 별도 호출).
  Future<ReceivedCheers> receivedCheers() async {
    final res = await _dio.get<Map<String, dynamic>>('/cheers/received');
    return ReceivedCheers.fromJson(res.data!);
  }

  /// 받은 응원을 모두 확인 처리(홈 캐릭터 반응을 재생한 뒤 호출).
  Future<void> markCheersSeen() async {
    await _dio.post<Map<String, dynamic>>('/cheers/received/seen');
  }

  // ── 알림 ──────────────────────────────────────────────

  Future<NotificationBoard> notifications() async {
    final res = await _dio.get<Map<String, dynamic>>('/notifications');
    return NotificationBoard.fromJson(res.data!);
  }

  Future<int> unreadNotificationCount() async {
    final res =
        await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
    return res.data!['unread'] as int;
  }

  /// [id]가 없으면 전체 읽음 처리. 반환값은 남은 안 읽은 수.
  Future<int> markNotificationsRead({String? id}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/notifications/read',
      data: {'id': ?id},
    );
    return res.data!['unread'] as int;
  }

  /// 푸시 토큰 등록(멱등). 로그인 후 호출.
  Future<void> registerDevice(String token, String platform) async {
    await _dio.post<Map<String, dynamic>>(
      '/devices',
      data: {'token': token, 'platform': platform},
    );
  }

  /// 로그아웃 시 이 기기로 푸시가 더 오지 않게 해제.
  Future<void> unregisterDevice(String token) async {
    await _dio.delete<Map<String, dynamic>>('/devices/$token');
  }

  // ── 크루 ──────────────────────────────────────────────

  Future<CrewDetail> createCrew(
    String name, {
    String? description,
    required bool isPublic,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/crews', data: {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'isPublic': isPublic,
    });
    return CrewDetail.fromJson(res.data!);
  }

  /// 크루 설정(이름·소개·공개여부) 변경. 방장만. 넘긴 값만 바뀐다.
  Future<CrewDetail> updateCrew(
    String crewId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>('/crews/$crewId', data: {
      'name': ?name,
      'description': ?description,
      'isPublic': ?isPublic,
    });
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

  // ── 크루 탐방 / 가입 신청 ──────────────────────────────

  /// 공개 크루 탐방. q로 이름 검색.
  Future<List<CrewSummary>> discoverCrews({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>('/crews/discover',
        queryParameters: {if (q != null && q.isNotEmpty) 'q': q});
    return (res.data!['items'] as List)
        .map((e) => CrewSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 공개 크루에 가입 신청.
  Future<void> requestJoinCrew(String crewId) async {
    await _dio.post<Map<String, dynamic>>('/crews/$crewId/join-request');
  }

  /// 방장: 대기중 가입 신청 목록.
  Future<List<CrewJoinRequestItem>> crewJoinRequests(String crewId) async {
    final res =
        await _dio.get<Map<String, dynamic>>('/crews/$crewId/join-requests');
    return (res.data!['items'] as List)
        .map((e) => CrewJoinRequestItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 방장: 가입 신청 승인/거절.
  Future<void> respondJoinRequest(
      String crewId, String requestId, bool accept) async {
    final action = accept ? 'accept' : 'reject';
    await _dio.post<Map<String, dynamic>>(
        '/crews/$crewId/join-requests/$requestId/$action');
  }

  // ── 크루 초대 ──────────────────────────────────────────

  /// 방장: @nickname 초대(대기중 초대 생성). 상대가 수락해야 가입된다.
  Future<String> inviteToCrew(String crewId, String nickname) async {
    final res = await _dio
        .post<Map<String, dynamic>>('/crews/$crewId/invite', data: {'nickname': nickname});
    return res.data!['displayName'] as String;
  }

  /// 내가 받은 대기중 초대 목록.
  Future<List<CrewInvitation>> myCrewInvitations() async {
    final res = await _dio.get<Map<String, dynamic>>('/crews/invitations');
    return (res.data!['items'] as List)
        .map((e) => CrewInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 초대 수락/거절.
  Future<void> respondCrewInvitation(String invitationId, bool accept) async {
    final action = accept ? 'accept' : 'decline';
    await _dio
        .post<Map<String, dynamic>>('/crews/invitations/$invitationId/$action');
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

  /// 내 크루 글 수정(한마디 + 운동 태그). workoutLogId를 빈 문자열로 보내면 태그 제거.
  Future<void> editCrewPost(
    String postId, {
    String? message,
    String? workoutLogId,
  }) async {
    await _dio.patch<Map<String, dynamic>>('/crews/posts/$postId', data: {
      'message': message ?? '',
      'workoutLogId': workoutLogId ?? '',
    });
  }

  /// 내 크루 글 삭제(댓글·응원 함께 삭제).
  Future<void> deleteCrewPost(String postId) async {
    await _dio.delete<Map<String, dynamic>>('/crews/posts/$postId');
  }

  /// 내 운동 기록 삭제. 지급됐던 코인은 회수된다.
  Future<void> deleteWorkout(String workoutId) async {
    await _dio.delete<Map<String, dynamic>>('/workouts/$workoutId');
  }

  /// 내 운동 기록 수정. 검증·코인 보상이 다시 계산된다.
  /// photoRef를 안 보내면 기존 사진을 유지한다.
  Future<WorkoutResult> updateWorkout(
    String workoutId, {
    required String sport,
    required int durationSec,
    int? distanceM,
    int? steps,
    String? bodyPart,
    int? sets,
    String? photoRef,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>('/workouts/$workoutId',
        data: {
          'sport': sport,
          'durationSec': durationSec,
          'distanceM': ?distanceM,
          'steps': ?steps,
          'bodyPart': ?bodyPart,
          'sets': ?sets,
          'photoRef': ?photoRef,
        });
    final d = res.data!;
    return WorkoutResult(
      verified: d['verified'] as bool? ?? false,
      reward: d['reward'] as int? ?? 0,
      balance: d['balance'] as int? ?? 0,
    );
  }

  /// 크루 피드에 글 작성. 운동 태그(workoutLogId)는 선택.
  Future<void> createCrewPost(
    String crewId, {
    String? workoutLogId,
    String? message,
  }) async {
    await _dio.post<Map<String, dynamic>>('/crews/$crewId/posts', data: {
      'workoutLogId': ?workoutLogId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
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
