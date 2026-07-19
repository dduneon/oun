import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 누적 운동 횟수로 계산한 크루 레벨 정보.
class CrewLevelInfo {
  const CrewLevelInfo(this.level, this.intoLevel, this.levelSpan, this.total);
  final int level; // 현재 크루 레벨
  final int intoLevel; // 현재 레벨에서 쌓은 횟수
  final int levelSpan; // 이번 레벨→다음 레벨에 필요한 횟수
  final int total; // 누적 총 횟수

  double get ratio =>
      levelSpan == 0 ? 1 : (intoLevel / levelSpan).clamp(0.0, 1.0);
  int get toNext => (levelSpan - intoLevel).clamp(0, levelSpan);
}

/// 누적 횟수 → 레벨. 레벨이 오를수록 다음 레벨에 필요한 횟수가 늘어난다.
CrewLevelInfo crewLevelOf(int total) {
  var level = 1;
  var remaining = total;
  var need = 40; // Lv1→2에 필요
  while (remaining >= need) {
    remaining -= need;
    level++;
    need += 20; // 다음 레벨은 더 많이 필요
  }
  return CrewLevelInfo(level, remaining, need, total);
}

/// 레벨 보상 정의. 해당 레벨 도달 시 크루원 전원에게 지급.
class CrewLevelReward {
  const CrewLevelReward(this.level, this.label, {this.coins = 0});
  final int level;
  final String label;
  final int coins;
}

const crewLevelRewards = [
  CrewLevelReward(2, '전원 코인 50', coins: 50),
  CrewLevelReward(3, '전원 코인 100', coins: 100),
  CrewLevelReward(5, '크루 전용 뱃지'),
  CrewLevelReward(7, '전원 코인 200', coins: 200),
  CrewLevelReward(10, '크루 광장 배경 해금'),
];

/// 크루 레벨 카드: 현재 레벨 + 다음 레벨까지 진행바 + 누적 횟수.
class CrewLevelCard extends StatelessWidget {
  const CrewLevelCard({super.key, required this.info});
  final CrewLevelInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: OunColors.tabAccent,
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text('Lv',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: OunColors.onTabAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('크루 레벨 ${info.level}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: OunColors.textPrimary)),
                    Text('누적 ${info.total}회 운동',
                        style: const TextStyle(
                            fontSize: 11.5, color: OunColors.textMuted)),
                  ],
                ),
              ),
              Text('다음까지 ${info.toNext}회',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: OunColors.tabAccent)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: info.ratio,
              minHeight: 9,
              backgroundColor: OunColors.card,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(OunColors.tabAccent),
            ),
          ),
          const SizedBox(height: 6),
          Text('Lv.${info.level} → ${info.level + 1}  ·  ${info.intoLevel}/${info.levelSpan}',
              style: const TextStyle(fontSize: 10.5, color: OunColors.textFaint)),
        ],
      ),
    );
  }
}

/// 레벨 보상 목록: 도달한 레벨은 받기/받음, 아직이면 잠김.
class CrewLevelRewardList extends StatefulWidget {
  const CrewLevelRewardList({super.key, required this.level});
  final int level;

  @override
  State<CrewLevelRewardList> createState() => _CrewLevelRewardListState();
}

class _CrewLevelRewardListState extends State<CrewLevelRewardList> {
  final _claimed = <int>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('레벨 보상',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textMuted)),
          const SizedBox(height: 10),
          for (var i = 0; i < crewLevelRewards.length; i++) ...[
            if (i > 0)
              const Divider(height: 16, color: OunColors.cardBorder),
            _rewardRow(crewLevelRewards[i]),
          ],
        ],
      ),
    );
  }

  Widget _rewardRow(CrewLevelReward r) {
    final unlocked = widget.level >= r.level;
    final claimed = _claimed.contains(r.level);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: unlocked
                ? OunColors.tabAccent.withValues(alpha: 0.14)
                : OunColors.card,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text('${r.level}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: unlocked ? OunColors.tabAccent : OunColors.textFaint)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(r.label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color:
                      unlocked ? OunColors.textPrimary : OunColors.textMuted)),
        ),
        if (!unlocked)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 13, color: OunColors.textFaint),
              const SizedBox(width: 3),
              Text('Lv.${r.level}',
                  style: const TextStyle(
                      fontSize: 11, color: OunColors.textFaint)),
            ],
          )
        else if (claimed)
          const Icon(Icons.check_circle_rounded,
              size: 20, color: OunColors.tabAccent)
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OunColors.tabAccent,
              foregroundColor: OunColors.onTabAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() => _claimed.add(r.level));
              OunToast.show(
                context,
                r.coins > 0 ? '전원에게 +${r.coins} 코인!' : '${r.label} 획득!',
                kind: OunToastKind.success,
                icon: r.coins > 0 ? Icons.paid_rounded : Icons.emoji_events,
              );
            },
            child: const Text('받기',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}
