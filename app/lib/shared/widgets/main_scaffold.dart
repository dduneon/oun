import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'floating_tab_bar.dart';

/// 하단 탭 셸. StatefulNavigationShell로 각 탭 상태를 유지한다
/// (홈의 Unity 인스턴스가 탭 전환 시 재로드되지 않도록 IndexedStack 기반).
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    FloatingTabItem(Icons.home_outlined, Icons.home, '홈'),
    FloatingTabItem(Icons.fitness_center_outlined, Icons.fitness_center, '기록'),
    FloatingTabItem(Icons.storefront_outlined, Icons.storefront, '상점'),
    FloatingTabItem(Icons.groups_outlined, Icons.groups, '크루'),
    FloatingTabItem(Icons.person_outline, Icons.person, '마이'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: FloatingTabBar(
        currentIndex: navigationShell.currentIndex,
        items: _items,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
