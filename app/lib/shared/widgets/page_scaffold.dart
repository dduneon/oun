import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'floating_tab_bar.dart';

/// 탭 화면 공통 스캐폴드: 상단 제목 + 스크롤 + 플로팅 탭바 여백 확보.
///
/// [onRefresh]를 주면 당겨서 새로고침이 붙는다. 서버가 source of truth인데
/// 탭 화면은 계속 살아 있어서, 사용자가 직접 다시 읽을 수단이 필요하다.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final bottomPad =
        MediaQuery.viewPaddingOf(context).bottom + FloatingTabBar.reservedSpace;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottomPad),
      // 내용이 짧아도 당길 수 있어야 새로고침이 걸린다.
      physics: onRefresh == null
          ? null
          : const AlwaysScrollableScrollPhysics(),
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
    );

    // 불투명 배경으로 전역 Unity 뷰를 가린다(홈만 투명).
    return ColoredBox(
      color: OunColors.background,
      child: SafeArea(
        bottom: false,
        child: onRefresh == null
            ? list
            : RefreshIndicator(
                onRefresh: onRefresh!,
                color: OunColors.tabAccent,
                backgroundColor: OunColors.surface,
                child: list,
              ),
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
