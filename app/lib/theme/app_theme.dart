import 'package:flutter/material.dart';

/// 오운 웜톤 색상 시스템 + 테마.
class OunColors {
  static const seed = Color(0xFFE8A87C); // 메인 포인트
  static const background = Color(0xFFFDF6F0); // 스캐폴드 배경
  static const card = Color(0xFFF3E9DF); // 카드/캐릭터 무대 (Unity 배경과 일치)
  static const cardBorder = Color(0xFFE8D5C4);
  static const textPrimary = Color(0xFF5C4033);
  static const textMuted = Color(0xFF9C8B7D);
  static const textFaint = Color(0xFFBBA99B);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: OunColors.seed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: OunColors.background,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: OunColors.background,
        indicatorColor: OunColors.seed.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, color: OunColors.textPrimary),
        ),
      ),
    );
  }
}
