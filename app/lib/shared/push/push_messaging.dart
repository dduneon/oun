import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';
import '../global_keys.dart';
import '../widgets/oun_toast.dart';

/// FCM 푸시 등록·수신.
///
/// **Firebase 설정 파일(`GoogleService-Info.plist` / `google-services.json`)이
/// 없으면 조용히 비활성**된다 — 초기화 실패를 흡수해서, 설정 전에도 앱은
/// 정상 동작하고 인앱 알림함만으로 굴러간다. 푸시는 어디까지나 부가 전달 경로다.
class PushMessaging {
  PushMessaging(this._ref);

  final Ref _ref;
  String? _token;
  bool _started = false;

  bool get enabled => _token != null;

  /// 로그인 직후 호출. 권한 요청 → 토큰 발급 → 서버 등록 → 수신 리스너.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase 설정 미완료(프로젝트/plist 없음) → 푸시 없이 계속.
      _started = false;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) await _register(token);

      // 토큰은 재설치·복원 등으로 갱신된다. 갱신될 때마다 다시 등록.
      messaging.onTokenRefresh.listen(_register);

      // 포그라운드 수신: OS 배너가 안 뜨므로 앱 안에서 직접 알린다.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    } catch (_) {
      // 권한 거부·네트워크 실패 등 — 푸시만 포기하고 앱은 그대로.
    }
  }

  /// 로그아웃 시 이 기기로 더 이상 푸시가 오지 않게 해제.
  Future<void> stop() async {
    final token = _token;
    _token = null;
    _started = false;
    if (token == null) return;
    try {
      await _ref.read(apiClientProvider).unregisterDevice(token);
    } catch (_) {
      // 해제 실패는 무시 — 서버가 폐기 토큰을 전송 실패 시 정리한다.
    }
  }

  Future<void> _register(String token) async {
    try {
      await _ref
          .read(apiClientProvider)
          .registerDevice(token, Platform.isIOS ? 'ios' : 'android');
      _token = token;
    } catch (_) {
      // 등록 실패 → 다음 갱신/재로그인에 다시 시도.
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    // 서버가 이미 알림 행을 만들었으니, 화면에 보이는 수치를 새로 고친다.
    _ref.invalidate(unreadNotificationsProvider);
    _ref.invalidate(notificationsProvider);
    if (message.data['type'] == 'cheer') {
      // 홈 캐릭터가 반응하도록 미확인 응원을 다시 읽는다.
      _ref.invalidate(receivedCheersProvider);
    }

    final body = message.notification?.body;
    final context = rootMessengerKey.currentContext;
    if (body != null && body.isNotEmpty && context != null) {
      OunToast.show(context, body, kind: OunToastKind.cheer);
    }
  }
}

final pushMessagingProvider =
    Provider<PushMessaging>((ref) => PushMessaging(ref));
