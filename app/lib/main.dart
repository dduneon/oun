import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/auth/social_sign_in.dart';
import 'shared/system_ui.dart';

void main() {
  // Firebase 초기화(푸시)가 바인딩을 먼저 요구한다.
  WidgetsFlutterBinding.ensureInitialized();
  restoreSystemBars();
  initSocialSignIn();
  runApp(const ProviderScope(child: OunApp()));
}
