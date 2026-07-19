import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 업적 하나: 조건을 달성하면 영구히 남는 뱃지.
class Achievement {
  const Achievement(this.icon, this.name, this.condition, {this.earned = false});
  final IconData icon;
  final String name;
  final String condition;
  final bool earned;
}

// 목데이터. 실제로는 서버가 달성 여부를 판정한다.
const _achievements = [
  Achievement(Icons.directions_walk, '첫 걸음', '첫 운동 기록', earned: true),
  Achievement(Icons.local_fire_department, '일주일 개근', '7일 연속 기록', earned: true),
  Achievement(Icons.wb_twilight, '아침형 인간', '아침 운동 5회', earned: true),
  Achievement(Icons.photo_camera, '인증왕', '인증 사진 10장', earned: true),
  Achievement(Icons.calendar_month, '한 달 개근', '30일 연속 기록'),
  Achievement(Icons.directions_run, '러너', '누적 러닝 50km'),
  Achievement(Icons.fitness_center, '철의 의지', '웨이트 30회'),
  Achievement(Icons.groups, '크루 데뷔', '첫 크루 가입', earned: true),
  Achievement(Icons.favorite, '응원단장', '응원 100회 보내기'),
  Achievement(Icons.checkroom, '멋쟁이', '아이템 10개 보유'),
  Achievement(Icons.nightlight_round, '올빼미', '밤 운동 5회'),
  Achievement(Icons.emoji_events, '백일의 약속', '100일 연속 기록'),
];

/// 업적 화면: 달성/미달성 뱃지 그리드.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final earned = _achievements.where((a) => a.earned).length;
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
      body: ListView(
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
                      Text('전체 ${_achievements.length}개 중',
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
                      value: earned / _achievements.length,
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
            children: [for (final a in _achievements) _Badge(a)],
          ),
        ],
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
            child: Icon(a.icon,
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
