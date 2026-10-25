import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:oun_app/features/health/health_workout.dart';
import 'package:oun_app/features/record/workout_editor.dart';
import 'package:oun_app/features/record/recent_workout_shortcuts.dart';
import 'package:oun_app/shared/api/api_client.dart';
import 'package:oun_app/shared/api/models.dart';
import 'package:oun_app/shared/api/providers.dart';

class CapturingApi extends ApiClient {
  Map<String, dynamic>? submitted;
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
  }) async {
    submitted = {
      ...details,
      'sport': sport,
      'durationSec': durationSec,
      'distanceM': distanceM,
      'sets': sets,
    };
    throw Exception('offline');
  }
}

void main() {
  HealthDataPoint point({int seconds = 1805, String id = 'watch-123'}) =>
      HealthDataPoint(
        uuid: id,
        value: WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.RUNNING,
          totalDistance: 5000,
          totalDistanceUnit: HealthDataUnit.METER,
          totalEnergyBurned: 250,
          totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
        ),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.MINUTE,
        dateFrom: DateTime(2026, 1, 1, 20),
        dateTo: DateTime(2026, 1, 1, 20).add(Duration(seconds: seconds)),
        sourcePlatform: HealthPlatformType.appleHealth,
        sourceDeviceId: 'watch',
        sourceId: 'apple',
        sourceName: 'Watch',
      );

  test('날짜·초·거리·칼로리와 원본 ID를 보존하고 지원 범위 밖 운동은 제외한다', () {
    final workout = HealthWorkout.fromPoint(point())!;
    expect(workout.id, 'watch-123');
    expect(workout.sport, 'running');
    expect(workout.durationSec, 1805);
    expect(workout.distanceM, 5000);
    expect(workout.calories, 250);
    expect(HealthWorkout.fromPoint(point(seconds: 0)), isNull);
    expect(HealthWorkout.fromPoint(point(seconds: 21601)), isNull);
    expect(HealthWorkout.fromPoint(point(id: '')), isNull);
  });

  testWidgets('선택한 운동만 저장하고 재시도에도 원본 ID와 입력을 유지한다', (tester) async {
    final api = CapturingApi();
    final imported = HealthWorkout.fromPoint(point())!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(body: WorkoutEditor(imported: imported)),
        ),
      ),
    );
    expect(api.submitted, isNull);
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    expect(api.submitted, containsPair('externalId', 'watch-123'));
    expect(api.submitted, containsPair('source', 'healthkit'));
    expect(api.submitted, containsPair('durationSec', 1805));
    expect(
      api.submitted,
      containsPair('performedAt', imported.start.toUtc().toIso8601String()),
    );
    expect(api.submitted, containsPair('distanceM', 5000));
    expect(find.text('5.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('건강 앱이 제공하지 않은 웨이트 세트 수를 만들어 저장하지 않는다', (tester) async {
    final api = CapturingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: WorkoutEditor(
              imported: HealthWorkout(
                id: 'weight',
                source: 'health_connect',
                sport: 'weight',
                start: DateTime(2026, 1, 1),
                durationSec: 1800,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    expect(api.submitted, isNotNull);
    expect(api.submitted!['sets'], isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('최근 운동에서 상세 진입 없이 오늘의 새 기록을 만든다', (tester) async {
    final api = CapturingApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          recentWorkoutsProvider.overrideWith(
            (ref) async => [
              Workout(
                id: 'old',
                sport: 'running',
                durationSec: 1810,
                distanceM: 5000,
                performedAt: DateTime(2020, 1, 1),
                source: 'healthkit',
                note: '예전 메모',
                calories: 200,
                photoUrl: 'https://example.com/old.jpg',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RecentWorkoutShortcuts()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('러닝'));
    await tester.pumpAndSettle();
    expect(find.text('다시 기록하기'), findsOneWidget);
    expect(find.text('예전 메모'), findsNothing);
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    final data = api.submitted!;
    expect(data['durationSec'], 1810);
    expect(data['distanceM'], 5000);
    expect(data.containsKey('externalId'), isFalse);
    expect(data.containsKey('source'), isFalse);
    expect(data['calories'], isNull);
    expect(data['note'], '');
    expect(
      DateTime.parse(
        data['performedAt'] as String,
      ).difference(DateTime.now()).abs().inSeconds,
      lessThan(10),
    );
    expect(tester.takeException(), isNull);
  });
}
