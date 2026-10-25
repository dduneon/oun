import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';
import 'workout_editor.dart';

/// A new manual draft: original date, photo and health identity are not copied.
class RecentWorkoutShortcuts extends ConsumerWidget {
  const RecentWorkoutShortcuts({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recentWorkoutsProvider).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '지난 운동으로 빠르게 기록',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: OunColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '내용을 불러와 오늘 운동에 맞게 수정해요',
            style: TextStyle(fontSize: 12, color: OunColors.textMuted),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final workout in items.take(3))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: OunColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: OunColors.cardBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => showModalBottomSheet<bool>(
                          context: context,
                          useRootNavigator: true,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) =>
                              WorkoutEditor(editing: workout, repeat: true),
                        ),
                        child: SizedBox(
                          width: 166,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      sportIcons[workout.sport],
                                      size: 18,
                                      color: OunColors.tabAccent,
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.replay_rounded,
                                      size: 17,
                                      color: OunColors.textMuted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  workout.customSportName?.isNotEmpty == true
                                      ? workout.customSportName!
                                      : sportLabels[workout.sport] ?? '운동',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: OunColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${relativeDay(workout.performedAt)} · ${workout.minutes}분',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: OunColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
