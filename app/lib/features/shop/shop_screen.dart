import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';

/// 커스터마이징 상점 (무과금, 운동 재화). 서버 아이템/보유/구매.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _category = 0;
  // (표시명, 서버 카테고리)
  static const _categories = [
    ('의상', 'clothing'),
    ('헤어', 'hair'),
    ('소품', 'prop'),
    ('가구', 'furniture'),
  ];

  Future<void> _onTapItem(ShopItem it) async {
    final api = ref.read(apiClientProvider);
    if (it.owned) {
      // 이미 보유 → 바로 장착(입어보기)
      try {
        await api.equipItem(it.key);
        if (mounted) {
          OunToast.show(context, '${it.name} 입었어요', kind: OunToastKind.success);
        }
      } catch (_) {
        if (mounted) OunToast.show(context, '장착에 실패했어요');
      }
      return;
    }

    // 구매 확인
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OunColors.background,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(it.name,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: OunColors.textPrimary)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.paid_rounded, size: 16, color: OunColors.coin),
            const SizedBox(width: 5),
            Text('${it.price} 코인으로 구매할까요?',
                style: const TextStyle(
                    fontSize: 13.5, color: OunColors.textPrimary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소',
                style: TextStyle(color: OunColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OunColors.tabAccent,
              foregroundColor: OunColors.onTabAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('구매'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await api.orderItem(it.key);
      ref.invalidate(walletProvider);
      ref.invalidate(shopItemsProvider);
      ref.invalidate(achievementsProvider);
      if (mounted) {
        OunToast.show(context, '${it.name} 구매했어요', kind: OunToastKind.success);
      }
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('409') ? '코인이 부족해요' : '구매에 실패했어요';
      OunToast.show(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coin = ref.watch(walletProvider).maybeWhen(
          data: comma,
          orElse: () => '—',
        );
    final itemsAsync =
        ref.watch(shopItemsProvider(_categories[_category].$2));

    return PageScaffold(
      title: '상점',
      trailing: CoinChip(amount: coin),
      onRefresh: () => refreshTab(ref, OunTab.shop),
      children: [
        // 캐릭터 미리보기 (라이브 프리뷰 연동 예정)
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: OunColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.checkroom, size: 30, color: OunColors.textFaint),
                SizedBox(height: 6),
                Text('입어보기 미리보기',
                    style: TextStyle(fontSize: 12, color: OunColors.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _segment(),
        const SizedBox(height: 14),
        itemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: OunColors.tabAccent))),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('아이템을 불러오지 못했어요',
                  style: TextStyle(fontSize: 12, color: OunColors.textFaint)),
            ),
          ),
          data: (items) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [for (final it in items) _itemCard(it)],
          ),
        ),
      ],
    );
  }

  Widget _segment() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: OunColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < _categories.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _category = i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: _category == i ? OunColors.surface : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _categories[i].$1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _category == i
                          ? OunColors.textPrimary
                          : OunColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemCard(ShopItem it) {
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: () => _onTapItem(it),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _itemCardBody(it),
        ),
      ),
    );
  }

  Widget _itemCardBody(ShopItem it) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                        color: colorFromHex(it.colorHex),
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (it.owned)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: OunColors.tabAccent,
                          borderRadius: BorderRadius.circular(9)),
                      child: const Text('보유',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: OunColors.onTabAccent)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(it.name,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: OunColors.textPrimary)),
          const SizedBox(height: 3),
          if (it.owned)
            // 이미 보유한 아이템에는 가격 대신 상태를 보여준다
            const Text('보유중 · 탭해서 입기',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: OunColors.textMuted))
          else
            Row(
              children: [
                const Icon(Icons.paid_rounded,
                    size: 14, color: OunColors.coin),
                const SizedBox(width: 4),
                Text('${it.price}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: OunColors.textPrimary)),
              ],
            ),
        ],
      );
  }
}
