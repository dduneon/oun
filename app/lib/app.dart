import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class OunApp extends StatelessWidget {
  const OunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '오운',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
