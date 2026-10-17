import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/api/models.dart';
import '../../shared/api/providers.dart';
import '../../shared/format.dart';
import '../../shared/widgets/oun_toast.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../theme/app_theme.dart';
import '../character/character_avatar.dart';

/// 커스터마이징 상점 (무과금, 운동 재화). 서버 아이템/보유/구매.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _category = 0;

  /// true면 '내 아이템' — 구매해서 보유한 것만 모아 본다.
  bool _mine = false;

  /// 상점에서 입어보는 중인 아이템(슬롯 → 아이템). 서버 장착 상태 위에 덮어 미리보기에만 쓴다.
  final Map<String, ShopItem> _tryOn = {};

  /// 미리보기 아래 구매 버튼이 가리키는, 마지막으로 입어본 아이템.
  ShopItem? _trying;

  /// 캐릭터가 입는 카테고리 = 장착 슬롯. 가구는 입어볼 수 없다.
  static const _wearable = {'clothing', 'hair', 'prop'};
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
      // 이미 보유 → 탭할 때마다 장착/해제를 오간다. 슬롯 = 카테고리.
      try {
        if (it.equipped) {
          await api.unequipSlot(it.category);
        } else {
          await api.equipItem(it.key);
        }
        ref.invalidate(shopItemsProvider);
        ref.invalidate(equippedItemsProvider);
        if (mounted) {
          OunToast.show(
            context,
            it.equipped ? '${it.name} 벗었어요' : '${it.name} 장착했어요',
            kind: OunToastKind.success,
          );
        }
      } catch (_) {
        if (mounted) {
          OunToast.show(context, it.equipped ? '해제에 실패했어요' : '장착에 실패했어요');
        }
      }
      return;
    }

    if (_wearable.contains(it.category)) {
      // 탭하면 미리보기에 입혀 보고, 입어보는 중인 걸 다시 탭하면 벗긴다.
      // 구매는 미리보기의 구매 버튼으로만 한다.
      setState(() {
        if (_tryOn[it.category]?.key == it.key) {
          _tryOn.remove(it.category);
          if (_trying?.key == it.key) {
            _trying = _tryOn.values.isEmpty ? null : _tryOn.values.last;
          }
        } else {
          _tryOn[it.category] = it;
          _trying = it;
        }
      });
      return;
    }
    // 가구는 입어볼 수 없으니 바로 구매 확인.
    await _buy(it);
  }

  /// 입어보던 걸 모두 벗기고 지금 장착한 모습으로 되돌린다.
  void _resetTryOn() => setState(() {
        _tryOn.clear();
        _trying = null;
      });

  Future<void> _buy(ShopItem it) async {
    final api = ref.read(apiClientProvider);
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
      // 캐릭터가 입는 아이템(의상·헤어·소품)은 구매 즉시 장착해
      // 홈으로 돌아갔을 때 바로 3D 캐릭터에 보이게 한다.
      var equipped = false;
      if (_wearable.contains(it.category)) {
        try {
          await api.equipItem(it.key);
          equipped = true;
        } catch (_) {
          // 구매 자체는 끝났으므로 장착 실패를 구매 실패로 잘못 안내하지 않는다.
        }
      }
      if (mounted) {
        // 산 아이템은 이제 실제로 입고 있으니 입어보기 목록에서 뺀다.
        setState(() {
          _tryOn.remove(it.category);
          if (_trying?.key == it.key) _trying = null;
        });
      }
      ref.invalidate(walletProvider);
      ref.invalidate(shopItemsProvider);
      ref.invalidate(equippedItemsProvider);
      ref.invalidate(achievementsProvider);
      if (mounted) {
        OunToast.show(
          context,
          equipped ? '${it.name} 구매하고 장착했어요' : '${it.name} 구매했어요',
          kind: OunToastKind.success,
        );
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
        _preview(),
        const SizedBox(height: 14),
        _segment(
          labels: const ['상점', '내 아이템'],
          selected: _mine ? 1 : 0,
          onTap: (i) => setState(() {
            _mine = i == 1;
            // 내 아이템에서는 실제 장착 모습을 보여 준다.
            if (_mine) {
              _tryOn.clear();
              _trying = null;
            }
          }),
        ),
        const SizedBox(height: 8),
        _segment(
          labels: [for (final c in _categories) c.$1],
          selected: _category,
          onTap: (i) => setState(() => _category = i),
          compact: true,
        ),
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
          data: (all) {
            // 상점에는 아직 없는 것만, 내 아이템에는 보유한 것만.
            final items = all.where((it) => it.owned == _mine).toList();
            if (items.isEmpty) return _empty(soldOut: all.isNotEmpty);
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              children: [for (final it in items) _itemCard(it)],
            );
          },
        ),
      ],
    );
  }

  /// 캐릭터 미리보기. 지금 장착한 모습 위에 상점에서 입어보는 아이템을 덮어 그린다.
  /// 내 아이템에서 장착/해제하면 서버 장착 상태가 바뀌어 바로 반영된다.
  Widget _preview() {
    final equipment = {
      ...?ref.watch(equippedItemsProvider).value,
      for (final e in _tryOn.entries) e.key: e.value.key,
    };
    final look = CharacterLook(
      gender: ref.watch(authProvider.select((a) => a.profile?.gender)) ?? 'f',
      equipment: equipment,
    );
    final trying = _trying;
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: OunColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Center(child: LivingCharacter(look: look)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trying != null
                      ? '${trying.name} 입어보는 중'
                      : _mine
                          ? '지금 내 모습'
                          : '입어보기',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: OunColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  trying != null
                      ? '마음에 들면 구매하면 바로 입혀 줄게요'
                      : _mine
                          ? '아이템을 탭해 장착하면 홈에도 이 모습으로 보여요'
                          : '아이템을 탭하면 구매 전에 입어볼 수 있어요',
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, color: OunColors.textMuted),
                ),
                if (trying != null) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: OunColors.tabAccent,
                      foregroundColor: OunColors.onTabAccent,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _buy(trying),
                    icon: const Icon(Icons.paid_rounded, size: 16),
                    label: Text('${trying.price} 구매'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                    onPressed: _resetTryOn,
                    child: const Text('원래대로',
                        style: TextStyle(
                            fontSize: 12.5, color: OunColors.textMuted)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [soldOut]: 상점에 있던 걸 다 모았다(아니면 아직 내 캐릭터용 아이템이 없음).
  Widget _empty({required bool soldOut}) {
    final name = _categories[_category].$1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 30, color: OunColors.textFaint),
            const SizedBox(height: 8),
            Text(
                _mine
                    ? '아직 보유한 $name 아이템이 없어요'
                    : soldOut
                        ? '$name 아이템을 모두 모았어요'
                        : '새 $name 아이템을 준비하고 있어요',
                style: const TextStyle(fontSize: 13, color: OunColors.textMuted)),
            if (_mine) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _mine = false),
                child: const Text('상점 둘러보기',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: OunColors.tabAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// [compact]는 카테고리 줄(조금 작게), 아니면 상점/내 아이템 전환.
  Widget _segment({
    required List<String> labels,
    required int selected,
    required ValueChanged<int> onTap,
    bool compact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: OunColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: compact ? 6 : 8),
                  decoration: BoxDecoration(
                    color: selected == i
                        ? (compact ? OunColors.surface : OunColors.tabAccent)
                        : null,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 12.5 : 13.5,
                      fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
                      color: selected == i
                          ? (compact
                              ? OunColors.textPrimary
                              : OunColors.onTabAccent)
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
    final trying = !it.owned && _tryOn[it.category]?.key == it.key;
    return Material(
      color: OunColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: trying
            ? const BorderSide(color: OunColors.tabAccent, width: 2)
            : const BorderSide(color: OunColors.cardBorder),
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
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/shop/${it.key}.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.checkroom_rounded,
                        size: 40,
                        color: OunColors.textFaint,
                      ),
                    ),
                  ),
                ),
                if (it.owned || _tryOn[it.category]?.key == it.key)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: OunColors.tabAccent,
                          borderRadius: BorderRadius.circular(9)),
                      child: Text(
                          !it.owned
                              ? '입어보는 중'
                              : it.equipped
                                  ? '장착중'
                                  : '보유',
                          style: const TextStyle(
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
            Text(it.equipped ? '장착중 · 탭해서 해제' : '보유중 · 탭해서 장착',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: it.equipped
                        ? OunColors.tabAccent
                        : OunColors.textMuted))
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
