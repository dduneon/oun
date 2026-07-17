import 'package:flutter_test/flutter_test.dart';

import 'package:oun_app/main.dart';

void main() {
  testWidgets('오운 홈 화면이 렌더링된다', (WidgetTester tester) async {
    await tester.pumpWidget(const OunApp());

    expect(find.text('오운'), findsOneWidget);
    expect(find.text('오늘 운동 기록하기'), findsOneWidget);
  });
}
