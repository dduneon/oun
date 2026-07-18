import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'floating_tab_bar.dart';

/// 탭 화면 공통 스캐폴드: 상단 제목 + 스크롤 + 플로팅 탭바 여백 확보.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        MediaQuery.viewPaddingOf(context).bottom + FloatingTabBar.reservedSpace;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, 12, 18, bottomPad),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: OunColors.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// 재화 잔액 칩. 모든 화면에서 동일한 모양을 쓴다.
class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.amount});
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OunColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.paid_rounded, size: 15, color: OunColors.coin),
          const SizedBox(width: 5),
          Text(amount,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OunColors.textPrimary)),
        ],
      ),
    );
  }
}
