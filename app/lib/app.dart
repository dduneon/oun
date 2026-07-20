import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/login_screen.dart';
import 'router.dart';
import 'shared/api/providers.dart';
import 'shared/global_keys.dart';
import 'theme/app_theme.dart';
import 'unity/unity_stage.dart';

class OunApp extends ConsumerWidget {
  const OunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp.router(
      title: '오운',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: router,
      // 단일 Unity 뷰를 모든 라우트 뒤에 깔아둔다. 투명한 화면(홈·크루 광장)
      // 에서만 비쳐 보이고, 불투명 화면에서는 가려진다. 재마운트하지 않으므로
      // Unity는 앱 생명주기 동안 한 번만 로드된다.
      //
      // 로그인 전에는 라우터 위를 로그인/스플래시가 덮는다(인증 게이트).
      builder: (context, child) => Stack(
        children: [
          const Positioned.fill(child: UnityHost()),
          Positioned.fill(child: child ?? const SizedBox.shrink()),
          if (auth.status == AuthStatus.loggedOut)
            const Positioned.fill(child: LoginScreen())
          else if (auth.status == AuthStatus.restoring)
            const Positioned.fill(child: _Splash()),
        ],
      ),
    );
  }
}

/// 세션 복원 중 스플래시.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: OunColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, size: 44, color: OunColors.tabAccent),
            SizedBox(height: 14),
            Text('오운',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: OunColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
