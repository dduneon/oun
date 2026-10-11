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
    expect(find.text('34'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
