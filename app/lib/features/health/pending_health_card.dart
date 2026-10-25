import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';
import '../record/workout_editor.dart';
import 'health_import_screen.dart';

/// 홈 상단의 '아직 기록하지 않은 운동' 알림. 캐릭터 무대를 가리지 않도록
/// 하단 오늘 카드와 같은 프로스티드 톤으로 작게 띄운다.
class PendingHealthCard extends ConsumerWidget {
  const PendingHealthCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingHealthWorkoutsProvider);
    return pending.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Align(
        alignment: Alignment.centerRight,
        child: _Frosted(
          radius: 16,
          onTap: () {
            ref.invalidate(healthImportStatesProvider);
            ref.invalidate(pendingHealthWorkoutsProvider);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 15,
                  color: OunColors.textMuted,
                ),
                SizedBox(width: 5),
                Text(
                  '건강 앱 운동 다시 확인',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OunColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final workout = items.first;
        return _Frosted(
          radius: 18,
          onTap: () async {
            await showModalBottomSheet<bool>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => WorkoutEditor(imported: workout),
            );
            if (context.mounted) {
              ref.invalidate(pendingHealthWorkoutsProvider);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: OunColors.card,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    sportIcons[workout.sport] ?? Icons.sports_gymnastics,
                    size: 18,
                    color: OunColors.tabAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '아직 기록하지 않은 운동',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: OunColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${relativeDay(workout.start)} ${sportLabels[workout.sport] ?? '운동'} ${workout.durationSec ~/ 60}분 · 기록할까요?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: OunColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (items.length > 1)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        openHealthImport(context, onlyUnrecorded: true),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: OunColors.tabAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${items.length - 1}개 보기',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: OunColors.tabAccent,
                        ),
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: OunColors.textFaint,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 홈 오늘 카드와 같은 반투명 블러 카드.
class _Frosted extends StatelessWidget {
  const _Frosted({
    required this.radius,
    required this.onTap,
    required this.child,
  });
  final double radius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: OunColors.surface.withValues(alpha: 0.84),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: const BorderSide(color: OunColors.cardBorder),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: child,
          ),
        ),
      ),
    ),
  );
}
