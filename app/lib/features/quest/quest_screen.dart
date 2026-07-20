import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 개인 퀘스트: 일일 / 주간 / 도전. 진행·보상은 서버가 source of truth.
class QuestScreen extends ConsumerWidget {
  const QuestScreen({super.key});

  Future<void> _claim(BuildContext context, WidgetRef ref, Quest q) async {
    try {
      final result = await ref.read(apiClientProvider).claimQuest(q.key);
      ref.invalidate(questsProvider);
      ref.invalidate(walletProvider);
      ref.invalidate(profileProvider);
      if (context.mounted && result.reward > 0) {
        OunToast.show(context, '+${result.reward} 코인을 받았어요',
            kind: OunToastKind.success, icon: Icons.paid_rounded);
      }
    } catch (_) {
      if (context.mounted) OunToast.show(context, '보상 수령에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(questsProvider);
    return Scaffold(
      backgroundColor: OunColors.background,
      appBar: AppBar(
        backgroundColor: OunColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: OunColors.textPrimary,
        title: const Text('퀘스트',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: OunColors.tabAccent)),
        error: (_, _) => const Center(
          child: Text('퀘스트를 불러오지 못했어요',
              style: TextStyle(fontSize: 13, color: OunColors.textMuted)),
        ),
        data: (board) => ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          children: [
            const _SectionLabel('일일 퀘스트', sub: '매일 자정에 초기화돼요'),
            for (final q in board.daily)
              _QuestCard(quest: q, onClaim: () => _claim(context, ref, q)),
            const SizedBox(height: 18),
            const _SectionLabel('주간 퀘스트', sub: '월요일마다 새로 시작'),
            for (final q in board.weekly)
              _QuestCard(quest: q, onClaim: () => _claim(context, ref, q)),
            const SizedBox(height: 18),
            const _SectionLabel('도전 과제', sub: '꾸준함에 주는 큰 보상'),
            for (final q in board.challenge)
              _QuestCard(quest: q, onClaim: () => _claim(context, ref, q)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.sub});
  final String text;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(text,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: OunColors.textPrimary)),
            const SizedBox(width: 8),
            Text(sub,
                style:
                    const TextStyle(fontSize: 10.5, color: OunColors.textFaint)),
          ],
        ),
      );
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest, required this.onClaim});
  final Quest quest;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final q = quest;
    final done = q.state != 'in_progress';
    final ratio = (q.progress / q.goal).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: done
                  ? OunColors.tabAccent.withValues(alpha: 0.14)
                  : OunColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconFor(q.icon),
                size: 20,
                color: done ? OunColors.tabAccent : OunColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OunColors.textPrimary)),
                const SizedBox(height: 2),
                Text(q.sub,
                    style: const TextStyle(
                        fontSize: 10.5, color: OunColors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: OunColors.card,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              OunColors.tabAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${q.progress}/${q.goal}',
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: OunColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _RewardArea(quest: q, onClaim: onClaim),
        ],
      ),
    );
  }
}

class _RewardArea extends StatelessWidget {
  const _RewardArea({required this.quest, required this.onClaim});
  final Quest quest;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    switch (quest.state) {
      case 'claimable':
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: OunColors.tabAccent,
            foregroundColor: OunColors.onTabAccent,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            minimumSize: Size.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          onPressed: onClaim,
          child: Text('+${quest.reward} 받기',
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
        );
      case 'claimed':
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.check_circle_rounded,
              size: 22, color: OunColors.tabAccent),
        );
      default:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.paid_rounded, size: 14, color: OunColors.coin),
            const SizedBox(width: 3),
            Text('${quest.reward}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: OunColors.textPrimary)),
          ],
        );
    }
  }
}
