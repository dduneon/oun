import 'package:flutter/services.dart';

/// 상태바·내비게이션 바를 다시 세운다.
///
/// 안드로이드에서 UnityPlayer가 뜨면서 호스트 액티비티 창에 전체화면 플래그를
/// 걸어 시스템 바가 사라진다 — Unity의 Fullscreen Mode 설정이 임베드된 우리
/// 앱 창에까지 먹는다. iOS는 Unity가 창을 소유하지 않아 이런 일이 없다.
///
/// 그래서 앱 시작 시점 한 번으로는 부족하고, Unity가 준비 신호를 보낸 뒤에도
/// 다시 불러줘야 한다.
///
/// 홈은 캐릭터가 화면 끝까지 차는 화면이라 바를 밀어내지 않고 edge-to-edge로
/// 두고 투명하게만 만든다(각 화면은 이미 SafeArea로 여백을 확보한다).
void restoreSystemBars() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      // 배경이 밝은 크림색이라 아이콘은 어두워야 보인다.
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS 기준(반대로 읽는다)
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}
