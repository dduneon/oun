import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../record/workout_editor.dart';
import 'health_import_screen.dart';
import 'health_workout.dart';

/// 홈 캐릭터가 건네는 '아직 기록하지 않은 운동' 한마디.
String pendingHealthLine(List<HealthWorkout> items) {
  if (items.length > 1) return '기록 안 한 운동이 ${items.length}개 있어! 같이 정리할까?';
  final w = items.first;
  return '${relativeDay(w.start)} ${sportLabels[w.sport] ?? '운동'} '
      '${w.durationSec ~/ 60}분 했지? 기록해 줄까?';
}

/// 하나면 바로 기록 시트, 여러 개면 미기록 목록을 연다.
Future<void> openPendingHealth(
  BuildContext context,
  WidgetRef ref,
  List<HealthWorkout> items,
) async {
  if (items.length > 1) {
    await openHealthImport(context, onlyUnrecorded: true);
  } else {
    await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WorkoutEditor(imported: items.first),
    );
  }
  if (context.mounted) {
    ref.invalidate(healthImportStatesProvider);
    ref.invalidate(pendingHealthWorkoutsProvider);
  }
}
