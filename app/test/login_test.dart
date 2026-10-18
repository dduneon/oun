import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oun_app/features/auth/login_screen.dart';

void main() {
  testWidgets('랜딩에 회원가입·카카오 버튼이 있다', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: LoginScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
  });
}
