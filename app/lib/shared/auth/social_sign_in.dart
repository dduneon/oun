import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 카카오 네이티브 앱 키(카카오 개발자 콘솔 > 앱 키). 앱에 들어가는 공개 키다.
/// 바꾸면 iOS Info.plist의 URL 스킴(kakao<키>)과 Android 매니페스트도 같이 바꾼다
/// (BUILD.md "소셜 로그인"). 비어 있으면 카카오 버튼은 안내만 띄운다.
const kakaoNativeAppKey = '';

bool get kakaoReady => kakaoNativeAppKey.isNotEmpty;

/// 애플 로그인은 iOS에서만 보여 준다(안드로이드는 웹 연동이 따로 필요).
bool get appleSignInSupported => Platform.isIOS;

/// 앱 시작 때 한 번. 키가 없으면 건너뛴다.
void initSocialSignIn() {
  if (kakaoReady) KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
}

/// 카카오 access token. 카카오톡이 있으면 톡으로, 없으면 카카오 계정(웹)으로.
/// 사용자가 취소하면 null.
Future<String?> kakaoAccessToken() async {
  try {
    if (await isKakaoTalkInstalled()) {
      try {
        return (await UserApi.instance.loginWithKakaoTalk()).accessToken;
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') return null;
        // 톡에 카카오 계정이 연결돼 있지 않은 경우 등 → 계정 로그인으로.
      }
    }
    return (await UserApi.instance.loginWithKakaoAccount()).accessToken;
  } on PlatformException catch (e) {
    if (e.code == 'CANCELED') return null;
    rethrow;
  } on KakaoClientException catch (e) {
    if (e.reason == ClientErrorCause.cancelled) return null;
    rethrow;
  } on KakaoAuthException catch (e) {
    if (e.error == AuthErrorCause.accessDenied) return null;
    rethrow;
  }
}

/// 애플 identity token과 (첫 로그인 때만 오는) 이름. 취소하면 null.
Future<({String identityToken, String? name})?> appleCredential() async {
  try {
    final c = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.fullName],
    );
    final token = c.identityToken;
    if (token == null) return null;
    return (identityToken: token, name: _fullName(c.givenName, c.familyName));
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) return null;
    rethrow;
  }
}

/// 한글 이름은 성+이름 붙여서(김오운), 그 밖에는 이름 성(Oun Kim).
String? _fullName(String? given, String? family) {
  final g = given?.trim() ?? '';
  final f = family?.trim() ?? '';
  if (g.isEmpty && f.isEmpty) return null;
  final hangul = RegExp(r'[가-힣]');
  if (hangul.hasMatch(g) || hangul.hasMatch(f)) return '$f$g';
  return [g, f].where((s) => s.isNotEmpty).join(' ');
}
