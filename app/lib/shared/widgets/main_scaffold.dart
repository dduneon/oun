import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../unity/unity_stage.dart';
import 'floating_tab_bar.dart';

/// 하단 탭 셸. StatefulNavigationShell로 각 탭 상태를 유지한다
/// (홈의 Unity 인스턴스가 탭 전환 시 재로드되지 않도록 IndexedStack 기반).
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  static const _homeIndex = 0;

  static const _items = [
    FloatingTabItem(Icons.home_outlined, Icons.home, '홈'),
    FloatingTabItem(Icons.fitness_center_outlined, Icons.fitness_center, '기록'),
    FloatingTabItem(Icons.storefront_outlined, Icons.storefront, '상점'),
    FloatingTabItem(Icons.groups_outlined, Icons.groups, '소셜'),
    FloatingTabItem(Icons.person_outline, Icons.person, '마이'),
  ];

  int? _lastIndex;

  @override
  Widget build(BuildContext context) {
    final index = widget.navigationShell.currentIndex;
    // 홈 탭이 보이는 순간에만 Unity를 홈 씬으로 되돌린다. 크루에서 나올 때
    // 불투명한 탭 위에서 rect를 바꾸면 플랫폼 뷰가 한 프레임 삐져나오므로,
    // 홈 복귀(씬 전환 + 전체 화면 rect)를 홈 탭까지 미룬다. 홈 화면은 투명이라
    // UnityHost의 가림막이 최상단에 있어 전환 순간(줌)이 가려진다.
    if (index != _lastIndex) {
      _lastIndex = index;
      if (index == _homeIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(unitySceneProvider.notifier).showHome();
          ref.read(unityViewportProvider.notifier).setRect(null);
        });
      }
    }

    return Scaffold(
      extendBody: true,
      // 투명: 홈 탭(투명 화면)에서는 뒤의 Unity가 비치고,
      // 다른 탭은 각 화면(PageScaffold)이 불투명 배경으로 가린다.
      backgroundColor: Colors.transparent,
      body: widget.navigationShell,
      bottomNavigationBar: FloatingTabBar(
        currentIndex: index,
        items: _items,
        onTap: (i) {
          // 홈 복귀는 아래 post-frame에서야 시작되므로, 탭이 그려지는 첫 프레임에는
          // 아직 크루 씬이 남아 있다(홈은 투명이라 그대로 비친다). 탭을 누른
          // 이 시점에 미리 가려둔다 — 내리는 건 새 씬이 준비된 뒤 UnityHost가 한다.
          if (i == _homeIndex &&
              ref.read(unitySceneProvider).scene != UnityScene.home) {
            ref.read(unityCoverProvider.notifier).raise();
          }
          widget.navigationShell.goBranch(
            i,
            initialLocation: i == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
