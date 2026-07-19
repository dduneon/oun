import 'package:dio/dio.dart';

/// 오운 백엔드 API 베이스 URL.
///
/// - iOS 시뮬레이터: 호스트와 네트워크를 공유하므로 localhost 사용.
/// - Android 에뮬레이터: 호스트는 10.0.2.2 로 접근(필요 시 교체).
/// 실기기 테스트 시 개발 PC의 LAN IP로 바꾼다.
const String kApiBaseUrl = String.fromEnvironment(
  'OUN_API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

/// 얇은 API 클라이언트. 액세스 토큰을 메모리에 보관하고 요청에 자동 첨부한다.
///
/// MVP 단계 — 한 흐름(dev 로그인 → 지갑) 확인용. 토큰을 메모리에만 두어
/// 네이티브 저장소 플러그인을 추가하지 않는다(앱 빌드 설정 무변경).
/// 영구 보관(secure storage)·refresh 재시도는 다음 단계.
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
      ),
    );
  }

  final Dio _dio;
  String? _accessToken;

  bool get hasSession => _accessToken != null;

  /// 개발용 로그인. 자격증명 없이 닉네임만으로 세션을 만든다.
  Future<void> devLogin(String nickname) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/dev',
      data: {'nickname': nickname},
    );
    _accessToken = res.data!['accessToken'] as String;
  }

  /// 세션이 없으면 dev 로그인으로 하나 만든다(최초 실행 편의).
  Future<void> ensureSession({String nickname = 'oun_me'}) async {
    if (!hasSession) {
      await devLogin(nickname);
    }
  }

  /// GET /wallet → 현재 코인 잔액.
  Future<int> wallet() async {
    final res = await _dio.get<Map<String, dynamic>>('/wallet');
    return res.data!['balance'] as int;
  }
}
