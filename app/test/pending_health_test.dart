import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/features/health/health_workout.dart';
import 'package:oun_app/features/health/pending_health_card.dart';
import 'package:oun_app/shared/api/providers.dart';

class LoggedIn extends AuthController {
  @override
  AuthState build() => const AuthState(AuthStatus.loggedIn);
}

class DeviceHealth extends HealthWorkouts {
  bool needs = false;
  int reads = 0;
  @override
  Future<bool> available() async => true;
  @override
  Future<bool> needsAuthorization() async => needs;
  @override
  Future<bool> authorize() async => throw StateError('홈에서 권한 요청 금지');
  @override
  Future<List<HealthWorkout>> readRecent() async {
    reads++;
    return [
      for (final id in ['saved', 'deleted', 'new'])
        HealthWorkout(
          id: id,
          source: 'healthkit',
          sport: 'running',
          start: DateTime(2026, 1, 1),
          durationSec: 1800,
        ),
    ];
  }
}

void main() {
  test('홈은 저장/삭제한 운동을 제외하고 미연결 상태에서 권한을 요청하지 않는다', () async {
    final health = DeviceHealth();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(LoggedIn.new),
        healthWorkoutsServiceProvider.overrideWithValue(health),
        healthImportStatesProvider.overrideWith(
          (ref) async => {
            'healthkit:saved': 'recorded',
            'healthkit:deleted': 'deleted',
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      (await container.read(
        pendingHealthWorkoutsProvider.future,
      )).map((w) => w.id),
      ['new'],
    );
    health.needs = true;
    container.invalidate(pendingHealthWorkoutsProvider);
    expect(await container.read(pendingHealthWorkoutsProvider.future), isEmpty);
    expect(health.reads, 1);
  });
  testWidgets('미기록 운동이 없으면 홈 카드를 숨긴다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingHealthWorkoutsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: PendingHealthCard())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('기록할까요?'), findsNothing);
  });
}
