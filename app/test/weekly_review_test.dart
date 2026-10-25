import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/features/record/weekly_review_screen.dart';
import 'package:oun_app/shared/api/models.dart';
import 'package:oun_app/shared/api/providers.dart';

WeeklyReview review({bool empty = false}) => WeeklyReview.fromJson({
  'weekStart': '2026-10-19',
  'weekEnd': '2026-10-25',
  'isCurrentWeek': true,
  'comparison': '지난주 같은 시점',
  'current': {
    'days': empty ? 0 : 3,
    'sessions': empty ? 0 : 4,
    'minutes': empty ? 0 : 120,
  },
  'previous': {'days': 2, 'sessions': 2, 'minutes': 60},
  'daily': [
    for (var i = 0; i < 7; i++)
      {
        'date': '2026-10-${19 + i}',
        'sessions': 0,
        'minutes': 0,
        'future': false,
      },
  ],
  'sports': empty
      ? []
      : [
          {'sport': 'running', 'minutes': 120, 'sessions': 4},
        ],
});
void main() {
  testWidgets('이번 주 회고와 비교 기준을 보여주고 이전 주로 이동한다', (tester) async {
    final requested = <String?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReviewProvider.overrideWith((ref, week) async {
            requested.add(week);
            return review();
          }),
        ],
        child: const MaterialApp(home: WeeklyReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3일, 나를 위해 움직였어요'), findsOneWidget);
    expect(find.text('지난주 같은 시점 비교'), findsOneWidget);
    await tester.tap(find.byTooltip('이전 주'));
    await tester.pumpAndSettle();
    expect(requested, contains('2026-10-12'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('빈 주는 오류나 꾸며낸 성과 없이 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReviewProvider.overrideWith(
            (ref, week) async => review(empty: true),
          ),
        ],
        child: const MaterialApp(home: WeeklyReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('잠깐 쉬어 가도 괜찮아요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
