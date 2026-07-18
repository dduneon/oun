import 'package:flutter/material.dart';

import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';

/// 커스터마이징 상점 (무과금, 운동 재화). 캐릭터 미리보기 + 카테고리 + 아이템 그리드.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _category = 0;
  static const _categories = ['의상', '헤어', '소품', '가구'];

  static const _items = [
    _Item('데일리 후드', 120, Color(0xFFD9B38C), owned: true),
    _Item('러너 티셔츠', 90, Color(0xFFB8C4A9)),
    _Item('니트 가디건', 210, Color(0xFFE0A9A0)),
    _Item('바람막이', 180, Color(0xFFA9BBD0)),
    _Item('후리스 조끼', 150, Color(0xFFD6C08A)),
    _Item('트랙 자켓', 240, Color(0xFFC9A9CE)),
  ];

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: '상점',
      trailing: const CoinChip(amount: '1,240'),
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
          children: [for (final it in _items) _itemCard(it)],
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
                    _categories[i],
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

  Widget _itemCard(_Item it) {
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: OunColors.cardBorder),
      ),
      child: InkWell(
        onTap: () => OunToast.show(
          context,
          it.owned ? '${it.name} 입어봤어요' : '${it.name} · ${it.price} 코인',
          kind: it.owned ? OunToastKind.success : OunToastKind.info,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: _itemCardBody(it),
        ),
      ),
    );
  }

  Widget _itemCardBody(_Item it) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                        color: it.color,
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
            const Text('보유중',
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

class _Item {
  const _Item(this.name, this.price, this.color, {this.owned = false});
  final String name;
  final int price;
  final Color color;
  final bool owned;
}
