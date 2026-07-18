import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../theme/app_theme.dart';

/// 친구 홈: 친구의 아바타(정적 표현) + 운동량 요약 + 최근 활동 + 응원.
///
/// 실시간 3D 아바타는 홈 탭의 단일 Unity 인스턴스 제약으로 띄울 수 없어,
/// 여기서는 정적 표현(추후 서버 렌더 스냅샷으로 교체)을 쓴다.
class FriendHomeScreen extends StatelessWidget {
  const FriendHomeScreen({
    super.key,
    required this.name,
    required this.initial,
    required this.color,
  });

  final String name;
  final String initial;
  final Color color;

  static const _week = ['월', '화', '수', '목', '금', '토', '일'];
  // 목데이터: 이번 주 운동 완료일(true) / 오늘 인덱스
  static const _weekDone = [true, true, false, true, true, false, false];
  static const _todayIndex = 4;

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
        title: Text('$name님의 홈',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          _avatarStage(),
          const SizedBox(height: 14),
          _statRow(),
          const SizedBox(height: 22),
          const _Label('이번 주'),
          const SizedBox(height: 10),
          _weekStrip(),
          const SizedBox(height: 22),
          const _Label('최근 활동'),
          const SizedBox(height: 10),
          const _ActivityRow(Icons.directions_run, '러닝', '오늘 · 5.2km', '32분'),
          const _ActivityRow(Icons.fitness_center, '웨이트', '어제 · 상체', '45분'),
          const _ActivityRow(Icons.directions_walk, '걷기', '3일 전 · 8,200보', '58분'),
          const SizedBox(height: 24),
          _cheerButton(context),
        ],
      ),
    );
  }

  /// 아바타 무대(정적). 실제로는 캐릭터 렌더 스냅샷이 들어갈 자리.
  Widget _avatarStage() {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initial,
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          const SizedBox(height: 14),
          Text('@$name',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Lv.6 · 오늘도 운동 중',
              style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
        ],
      ),
    );
  }

  Widget _statRow() {
    return Row(
      children: const [
        Expanded(child: _Stat(value: '12일', label: '연속 기록')),
        SizedBox(width: 9),
        Expanded(child: _Stat(value: '4일', label: '이번 주')),
        SizedBox(width: 9),
        Expanded(child: _Stat(value: '6.5h', label: '이번 주 시간')),
      ],
    );
  }

  Widget _weekStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _weekDone[i] ? OunColors.tabAccent : OunColors.card,
                    shape: BoxShape.circle,
                    border: i == _todayIndex
                        ? Border.all(color: OunColors.seed, width: 2)
                        : _weekDone[i]
                            ? null
                            : Border.all(color: OunColors.cardBorder),
                  ),
                  child: _weekDone[i]
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: OunColors.onTabAccent)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(_week[i],
                    style: const TextStyle(
                        fontSize: 10, color: OunColors.textMuted)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cheerButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: OunColors.tabAccent,
          foregroundColor: OunColors.onTabAccent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => OunToast.show(
          context,
          '$name님에게 응원을 보냈어요',
          kind: OunToastKind.cheer,
        ),
        icon: const Icon(Icons.favorite_rounded, size: 18),
        label: const Text('응원 보내기',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: OunColors.textPrimary));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: OunColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: OunColors.textMuted)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.icon, this.title, this.sub, this.value);
  final IconData icon;
  final String title;
  final String sub;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: OunColors.card, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: OunColors.tabAccent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: OunColors.textPrimary)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: OunColors.textMuted)),
              ],
            ),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
        ],
      ),
    );
  }
}
