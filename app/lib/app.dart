import 'package:flutter/material.dart';

import 'router.dart';
import 'shared/global_keys.dart';
import 'theme/app_theme.dart';
import 'unity/unity_stage.dart';

class OunApp extends StatelessWidget {
  const OunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '오운',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scaffoldMessengerKey: rootMessengerKey,
      routerConfig: router,
      // 단일 Unity 뷰를 모든 라우트 뒤에 깔아둔다. 투명한 화면(홈·크루 광장)
      // 에서만 비쳐 보이고, 불투명 화면에서는 가려진다. 재마운트하지 않으므로
      // Unity는 앱 생명주기 동안 한 번만 로드된다.
      builder: (context, child) => Stack(
        children: [
          const Positioned.fill(child: UnityHost()),
          Positioned.fill(child: child ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
