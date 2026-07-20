import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../theme/app_theme.dart';

/// 업적 화면: 달성/미달성 뱃지 그리드. 달성 여부는 서버가 판정한다.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(achievementsProvider);
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('업적',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OunColors.tabAccent)),
        error: (_, _) => const Center(
          child: Text('업적을 불러오지 못했어요',
              style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
        data: (data) {
          final (earned, total, items) = data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [
              // 요약 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OunColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: OunColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: OunColors.tabAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.emoji_events_rounded,
                          size: 23, color: OunColors.tabAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$earned개 달성',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: OunColors.textPrimary)),
                          Text('전체 $total개 중',
                              style: const TextStyle(
                                  fontSize: 11.5, color: OunColors.textMuted)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : earned / total,
                          minHeight: 8,
                          backgroundColor: OunColors.card,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              OunColors.tabAccent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.86,
                children: [for (final a in items) _Badge(a)],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.a);
  final Achievement a;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: a.earned ? OunColors.surface : OunColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: a.earned ? OunColors.tabAccent : OunColors.cardBorder,
            width: a.earned ? 1.2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: a.earned
                  ? OunColors.tabAccent
                  : OunColors.cardBorder.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(iconFor(a.icon, fallback: Icons.emoji_events),
                size: 21,
                color: a.earned ? OunColors.onTabAccent : OunColors.textFaint),
          ),
          const SizedBox(height: 8),
          Text(a.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color:
                      a.earned ? OunColors.textPrimary : OunColors.textMuted)),
          const SizedBox(height: 2),
          Text(a.condition,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9, color: OunColors.textFaint)),
        ],
      ),
    );
  }
}
