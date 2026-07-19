import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

enum QuestState { inProgress, claimable, claimed }

/// 개인 퀘스트 하나. 보상 재화는 실제로는 서버가 계산·지급한다(어뷰징 방지).
class Quest {
  Quest({
    required this.icon,
    required this.title,
    required this.sub,
    required this.reward,
    required this.progress,
    required this.goal,
    this.state = QuestState.inProgress,
  });

  final IconData icon;
  final String title;
  final String sub;
  final int reward;
  final int progress;
  final int goal;
  QuestState state;
}

/// 개인 퀘스트: 일일 / 주간 / 도전(연속 기록).
class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  // 목데이터. 실제로는 서버가 진행도·보상 상태의 source of truth.
  final _daily = [
    Quest(
        icon: Icons.check_circle_outline,
        title: '오늘 운동 기록하기',
        sub: '어떤 운동이든 1회 기록',
        reward: 20,
        progress: 1,
        goal: 1,
        state: QuestState.claimable),
    Quest(
        icon: Icons.timer_outlined,
        title: '30분 이상 움직이기',
        sub: '오늘 누적 운동 30분',
        reward: 30,
        progress: 32,
        goal: 30,
        state: QuestState.claimable),
    Quest(
        icon: Icons.photo_camera_outlined,
        title: '운동 인증 사진 남기기',
        sub: '기록에 사진 첨부',
        reward: 15,
        progress: 0,
        goal: 1),
  ];

  final _weekly = [
    Quest(
        icon: Icons.calendar_month_outlined,
        title: '이번 주 3회 운동',
        sub: '주간 운동 일수 채우기',
        reward: 80,
        progress: 2,
        goal: 3),
    Quest(
        icon: Icons.favorite_outline,
        title: '친구에게 응원 보내기',
        sub: '이번 주 3번 응원하기',
        reward: 40,
        progress: 3,
        goal: 3,
        state: QuestState.claimable),
  ];

  final _challenge = [
    Quest(
        icon: Icons.local_fire_department_outlined,
        title: '7일 연속 기록',
        sub: '쉬는 날도 휴식으로 기록하면 이어져요',
        reward: 150,
        progress: 5,
        goal: 7),
    Quest(
        icon: Icons.local_fire_department,
        title: '30일 연속 기록',
        sub: '한 달 개근 도전',
        reward: 500,
        progress: 12,
        goal: 30),
  ];

  void _claim(Quest q) {
    setState(() => q.state = QuestState.claimed);
    OunToast.show(context, '+${q.reward} 코인을 받았어요',
        kind: OunToastKind.success, icon: Icons.paid_rounded);
  }

  @override
  Widget build(BuildContext context) {
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          const _SectionLabel('일일 퀘스트', sub: '매일 자정에 초기화돼요'),
          for (final q in _daily) _QuestCard(quest: q, onClaim: () => _claim(q)),
          const SizedBox(height: 18),
          const _SectionLabel('주간 퀘스트', sub: '월요일마다 새로 시작'),
          for (final q in _weekly)
            _QuestCard(quest: q, onClaim: () => _claim(q)),
          const SizedBox(height: 18),
          const _SectionLabel('도전 과제', sub: '꾸준함에 주는 큰 보상'),
          for (final q in _challenge)
            _QuestCard(quest: q, onClaim: () => _claim(q)),
        ],
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
    final done = q.state != QuestState.inProgress;
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
            child: Icon(q.icon,
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
      case QuestState.claimable:
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
      case QuestState.claimed:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.check_circle_rounded,
              size: 22, color: OunColors.tabAccent),
        );
      case QuestState.inProgress:
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
