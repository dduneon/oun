import 'package:flutter/material.dart';

import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';

/// 마이룸·프로필·월말 리포트·설정.
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '마이',
      children: [
        // 프로필 카드
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
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: OunColors.card, shape: BoxShape.circle),
                child: const Icon(Icons.person,
                    size: 30, color: OunColors.textFaint),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('@oun_dduneon',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: OunColors.textPrimary)),
                  SizedBox(height: 3),
                  Text('Lv.7 · 연속 12일 · 재화 1,240',
                      style:
                          TextStyle(fontSize: 12, color: OunColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 메뉴
        Container(
          decoration: BoxDecoration(
            color: OunColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OunColors.cardBorder),
          ),
          child: Column(
            children: const [
              _MenuItem(Icons.cottage_outlined, '마이룸 꾸미기'),
              _MenuItem(Icons.description_outlined, '월말 리포트'),
              _MenuItem(Icons.shield_outlined, '기록 보호권 · 2개'),
              _MenuItem(Icons.notifications_outlined, '알림 설정'),
              _MenuItem(Icons.settings_outlined, '설정', last: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem(this.icon, this.label, {this.last = false});
  final IconData icon;
  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: OunColors.cardBorder)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: OunColors.tabAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: OunColors.textPrimary)),
          ),
          const Icon(Icons.chevron_right,
              size: 18, color: OunColors.textFaint),
        ],
      ),
    );
  }
}
