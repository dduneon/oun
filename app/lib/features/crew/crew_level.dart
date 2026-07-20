import 'package:flutter/material.dart';

import '../../shared/api/models.dart';
import '../../theme/app_theme.dart';

/// 크루 레벨 카드: 현재 레벨 + 다음 레벨까지 진행바 + 누적 횟수. (서버 값)
class CrewLevelCard extends StatelessWidget {
  const CrewLevelCard({super.key, required this.info});
  final CrewLevel info;

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
                child: const Text('Lv',
                    style: TextStyle(
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
          Text(
              'Lv.${info.level} → ${info.level + 1}  ·  ${info.intoLevel}/${info.levelSpan}',
              style:
                  const TextStyle(fontSize: 10.5, color: OunColors.textFaint)),
        ],
      ),
    );
  }
}

/// 레벨 보상 목록: 도달한 레벨은 받기/받음, 아직이면 잠김. 수령은 서버 처리.
class CrewLevelRewardList extends StatelessWidget {
  const CrewLevelRewardList({
    super.key,
    required this.rewards,
    required this.onClaim,
  });

  final List<CrewReward> rewards;
  final void Function(CrewReward) onClaim;

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
          for (var i = 0; i < rewards.length; i++) ...[
            if (i > 0) const Divider(height: 16, color: OunColors.cardBorder),
            _rewardRow(rewards[i]),
          ],
        ],
      ),
    );
  }

  Widget _rewardRow(CrewReward r) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: r.unlocked
                ? OunColors.tabAccent.withValues(alpha: 0.14)
                : OunColors.card,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text('${r.level}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color:
                      r.unlocked ? OunColors.tabAccent : OunColors.textFaint)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(r.label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: r.unlocked
                      ? OunColors.textPrimary
                      : OunColors.textMuted)),
        ),
        if (!r.unlocked)
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
        else if (r.claimed)
          const Icon(Icons.check_circle_rounded,
              size: 20, color: OunColors.tabAccent)
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OunColors.tabAccent,
              foregroundColor: OunColors.onTabAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => onClaim(r),
            child: const Text('받기',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }
}
