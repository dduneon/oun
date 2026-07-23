import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oun_app/features/record/record_screen.dart';

void main() {
  testWidgets('기록 화면이 렌더링된다', (WidgetTester tester) async {
    // 세션 복원이 보안 저장소를 읽으므로 목 값을 세팅.
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RecordScreen()),
      ),
    );
    await tester.pump();

    // 서버 없이도 정적 UI는 렌더된다.
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('오늘 기록하기'), findsOneWidget);
    expect(find.text('최근 기록'), findsOneWidget);
  });
}
