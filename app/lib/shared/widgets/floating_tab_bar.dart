import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FloatingTabItem {
  const FloatingTabItem(this.icon, this.selectedIcon, this.label);
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// 바닥에서 띄운 반투명 캡슐형 탭바.
/// 선택된 탭만 캡슐로 확장되며 라벨이 펼쳐진다(디자인 B).
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingTabItem> items;

  /// 화면 하단에서 이 탭바가 차지하는 대략적 높이(안전영역 제외).
  /// extendBody로 콘텐츠가 뒤까지 확장될 때, 하단 콘텐츠가 가려지지 않도록
  /// 이만큼 아래 여백을 확보한다.
  static const double reservedSpace = 84;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: OunColors.background.withValues(alpha: 0.66),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: OunColors.textPrimary.withValues(alpha: 0.08),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: OunColors.textPrimary.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < items.length; i++) _tab(i),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final selected = i == currentIndex;
    final item = items[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: selected
            ? const EdgeInsets.symmetric(horizontal: 15, vertical: 10)
            : const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? OunColors.tabAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              size: 22,
              color: selected ? OunColors.onTabAccent : OunColors.textMuted,
            ),
            if (selected) ...[
              const SizedBox(width: 7),
              Text(
                item.label,
                style: const TextStyle(
                  color: OunColors.onTabAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
