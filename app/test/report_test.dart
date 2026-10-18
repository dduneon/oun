import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/features/my/report_screen.dart';
import 'package:oun_app/shared/api/models.dart';

MonthlyReport report({
  int days = 0,
  int prev = 0,
  int streak = 0,
  bool current = false,
  String sport = 'running',
}) =>
    MonthlyReport.fromJson({
      'month': '2026-10',
      'firstMonth': '2026-08',
      'isCurrentMonth': current,
      'daysInMonth': 31,
      'workoutDays': days,
      'workouts': days,
      'totalMinutes': days * 30,
      'totalDistanceM': 0,
      'restDays': 0,
      'protectedDays': 0,
      'longestStreak': streak,
      'bySport': days == 0
          ? []
          : [
              {'sport': sport, 'count': days, 'minutes': days * 30},
            ],
      'topWeekday': null,
      'topTimeOfDay': null,
      'coinsEarned': 0,
      'cheersReceived': 0,
      'prevWorkoutDays': prev,
      'activeDates': ['2026-10-03', '2026-10-17'],
    });

void main() {
  test('운동한 날 수와 주 종목으로 칭호를 만든다', () {
    expect(reportHeadline(report(days: 13)).$1, '꾸준히 달리는 오운이');
    expect(reportHeadline(report(days: 3, sport: 'yoga')).$1, '천천히 마음을 고르는 오운이');
  });

  test('지난달보다 늘었으면 그걸, 아니면 연속 기록을 말해 준다', () {
    expect(reportHeadline(report(days: 8, prev: 5)).$2, '지난달보다 3일 더 움직였어요!');
    expect(reportHeadline(report(days: 4, prev: 9, streak: 4)).$2, contains('4일 연속'));
  });

  test('쉰 달도 탓하지 않는다', () {
    expect(reportHeadline(report()).$1, '푹 쉬어 간 오운이');
    expect(reportHeadline(report(current: true)).$1, '이제 막 시작하는 오운이');
  });

  test('운동한 날을 일자로 읽는다', () {
    expect(report(days: 2).activeDates, {3, 17});
  });
}
