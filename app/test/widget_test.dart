import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oun_app/features/record/record_screen.dart';

void main() {
  testWidgets('기록 화면이 렌더링된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RecordScreen()));

    expect(find.text('기록'), findsOneWidget);
    expect(find.text('최근 기록'), findsOneWidget);
    expect(find.text('전체 보기'), findsOneWidget);
  });
}
