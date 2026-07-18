import 'package:flutter/material.dart';

import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';

/// 운동 기록·입력. 주간 스트릭 + 종목 퀵스타트 + 최근 기록.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  static const _week = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '기록',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
            color: OunColors.card, borderRadius: BorderRadius.circular(16)),
        child: const Text('7월',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      ),
      children: [
        _card(
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: i < 5 ? OunColors.tabAccent : OunColors.card,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(_week[i],
                            style: const TextStyle(
                                fontSize: 10, color: OunColors.textMuted)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12, color: OunColors.textMuted),
                  children: [
                    TextSpan(text: '이번 주 '),
                    TextSpan(
                        text: '5일',
                        style: TextStyle(
                            color: OunColors.tabAccent,
                            fontWeight: FontWeight.w700)),
                    TextSpan(text: ' 운동 · 연속 12일'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: const [
            Expanded(child: _QuickStart(Icons.directions_run, '러닝')),
            SizedBox(width: 9),
            Expanded(child: _QuickStart(Icons.directions_walk, '걷기')),
            SizedBox(width: 9),
            Expanded(child: _QuickStart(Icons.fitness_center, '웨이트')),
            SizedBox(width: 9),
            Expanded(child: _QuickStart(Icons.directions_bike, '자전거')),
          ],
        ),
        const _SectionLabel('최근 기록'),
        const _RecordRow(Icons.directions_run, '러닝', '오늘 · 5.2km', '32분'),
        const _RecordRow(Icons.fitness_center, '웨이트', '어제 · 상체', '45분'),
        const _RecordRow(Icons.directions_walk, '걷기', '2일 전 · 8,200보', '58분'),
      ],
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: OunColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: OunColors.cardBorder),
        ),
        child: child,
      );
}

class _QuickStart extends StatelessWidget {
  const _QuickStart(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: OunColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: OunColors.tabAccent),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OunColors.textPrimary)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
      );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow(this.icon, this.title, this.sub, this.value);
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
                color: OunColors.card,
                borderRadius: BorderRadius.circular(11)),
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
