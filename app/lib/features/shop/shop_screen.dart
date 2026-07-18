import 'package:flutter/material.dart';

import '../../shared/widgets/feature_placeholder.dart';

/// 커스터마이징 상점 (순수 치장 아이템, 무과금 인게임 재화).
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: '상점',
      icon: Icons.storefront_outlined,
      description: '운동으로 모은 재화로 캐릭터를 꾸며요',
    );
  }
}
