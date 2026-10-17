import 'package:flutter/services.dart';

/// 상태바·내비게이션 바 스타일을 세운다.
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
