import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/features/record/workout_editor.dart';
import 'package:oun_app/shared/api/api_client.dart';
import 'package:oun_app/shared/api/models.dart';
import 'package:oun_app/shared/api/providers.dart';

class FailingApi extends ApiClient {
  @override
  Future<WorkoutResult> createWorkout({
    required String sport,
    required int durationSec,
    int? distanceM,
    int? steps,
    String? bodyPart,
    int? sets,
    String? photoRef,
    Map<String, dynamic> details = const {},
  }) async => throw Exception('offline');
}

void main() {
  testWidgets('저장 실패 후 입력을 유지한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(FailingApi())],
        child: const MaterialApp(
          home: Scaffold(body: WorkoutEditor(preset: '러닝')),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('distance')), '5.23');
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    expect(find.text('5.23'), findsOneWidget);
    expect(find.text('저장하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('기존 웨이트의 세트별 값을 복원한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: WorkoutEditor(
              editing: Workout(
                id: '1',
                sport: 'weight',
                durationSec: 1234,
                performedAt: DateTime(2026, 1, 1),
                exercises: const [
                  WorkoutExercise(
                    name: '벤치프레스',
                    sets: [WorkoutSet(weightKg: 57.5, reps: 8)],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('벤치프레스'), findsOneWidget);
    expect(find.text('57.5'), findsOneWidget);
    // 웨이트는 시·분만 보여 주고 초(34)는 숨긴 채 유지한다.
    expect(find.text('20분'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('종목의 지난 기록을 눌러 시간·거리를 채우고 날짜는 오늘로 둔다', (tester) async {
    final requested = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentBySportProvider.overrideWith((ref, sport) async {
            requested.add(sport);
            return sport == 'running'
                ? [
                    Workout(
                      id: 'r1',
                      sport: 'running',
                      durationSec: 2730,
                      distanceM: 7200,
                      performedAt: DateTime.now().subtract(
                        const Duration(days: 3),
                      ),
                    ),
                  ]
                : [];
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WorkoutEditor(preset: '러닝')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('지난 러닝 내용으로 채우기'), findsOneWidget);
    await tester.tap(find.text('3일 전 · 45분 · 7.2km'));
    await tester.pumpAndSettle();
    expect(find.text('45분 30초'), findsOneWidget);
    expect(find.text('7.2'), findsOneWidget);
    expect(find.textContaining('오늘'), findsWidgets);
    await tester.tap(find.text('웨이트'));
    await tester.pumpAndSettle();
    expect(requested, containsAll(['running', 'weight']));
    expect(find.textContaining('내용으로 채우기'), findsNothing);
  });

  testWidgets('소요 시간은 시트의 빠른 선택으로 고른다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: WorkoutEditor(preset: '웨이트')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('30분'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('duration')));
    await tester.pumpAndSettle();
    expect(find.text('얼마나 운동했나요?'), findsOneWidget);
    await tester.tap(find.text('1시간 30분'));
    await tester.pumpAndSettle();
    expect(find.text('1시간 30분'), findsOneWidget);
    expect(find.text('얼마나 운동했나요?'), findsNothing);
  });
}
