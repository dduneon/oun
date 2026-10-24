import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oun_app/shared/api/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oun_app/features/health/health_import_screen.dart';
import 'package:oun_app/features/health/health_workout.dart';

class FakeHealth extends HealthWorkouts {
  bool needsRequest = false, supported = true, deny = false;
  int requests = 0, reads = 0;
  List<HealthWorkout> rows = [
    HealthWorkout(
      id: 'one',
      source: 'healthkit',
      sport: 'running',
      start: DateTime(2026, 1, 1),
      durationSec: 1800,
    ),
  ];
  @override
  Future<bool> available() async => supported;
  @override
  Future<bool> needsAuthorization() async => needsRequest;
  @override
  Future<bool> authorize() async {
    requests++;
    needsRequest = deny;
    return !deny;
  }

  @override
  Future<List<HealthWorkout>> readRecent() async {
    reads++;
    return rows;
  }
}

void main() {
  Future<void> open(WidgetTester tester, FakeHealth health) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [healthImportStatesProvider.overrideWith((ref) async => {})],
        child: MaterialApp(home: HealthImportScreen(health: health)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('기존 연결은 진입 즉시 운동을 조회하고 새로고침도 권한을 요청하지 않는다', (tester) async {
    final health = FakeHealth();
    await open(tester, health);
    expect(health.reads, 1);
    expect(health.requests, 0);
    expect(find.text('러닝 · 30분'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    await tester.tap(find.text('새로고침'));
    await tester.pumpAndSettle();
    expect(health.reads, 2);
    expect(health.requests, 0);
  });

  testWidgets('첫 연결에서만 버튼을 표시하고 허용 후 목록으로 전환한다', (tester) async {
    final health = FakeHealth()..needsRequest = true;
    await open(tester, health);
    expect(health.reads, 0);
    expect(health.requests, 0);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(health.requests, 1);
    expect(health.reads, 1);
    expect(find.text('러닝 · 30분'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('권한 거절 시 반복 요청 없이 안내한다', (tester) async {
    final health = FakeHealth()
      ..needsRequest = true
      ..deny = true;
    await open(tester, health);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(health.requests, 1);
    expect(health.reads, 0);
    expect(find.text('운동 읽기를 허용하면 최근 운동을 볼 수 있어요.'), findsOneWidget);
  });

  testWidgets('빈 목록은 미연결로 단정하지 않고 설정 안내를 제공한다', (tester) async {
    final health = FakeHealth()..rows = [];
    await open(tester, health);
    expect(health.requests, 0);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('불러올 운동이 없어요'), findsOneWidget);
  });

  testWidgets('설정에서 앱으로 복귀하면 다시 조회한다', (tester) async {
    final health = FakeHealth();
    await open(tester, health);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(health.reads, 2);
    expect(health.requests, 0);
  });
  testWidgets('서버에 저장하거나 삭제한 운동은 다시 선택할 수 없다', (tester) async {
    final health = FakeHealth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthImportStatesProvider.overrideWith(
            (ref) async => {'healthkit:one': 'recorded'},
          ),
        ],
        child: MaterialApp(home: HealthImportScreen(health: health)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('기록 완료'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
  });
}
