import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../api/providers.dart';
import 'floating_tab_bar.dart';

/// 하단 탭 셸. StatefulNavigationShell로 각 탭 상태를 유지한다(IndexedStack 기반).
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
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
    if (index != _lastIndex) {
      final isFirstBuild = _lastIndex == null;
      _lastIndex = index;
      // 탭 화면은 IndexedStack으로 계속 살아 있어서 다시 열어도 스스로 서버를
      // 읽지 않는다. 탭이 보이는 순간 그 탭의 데이터를 다시 읽어, 다른 사람이
      // 만든 변화(친구 요청·크루 초대 등)가 바로 반영되게 한다.
      // (첫 빌드는 각 화면이 어차피 처음 읽으므로 건너뛴다)
      if (!isFirstBuild) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (ref.read(authProvider).status != AuthStatus.loggedIn) return;
          invalidateAll(ref, providersForTab(index));
        });
      }
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: OunColors.background,
      body: widget.navigationShell,
      bottomNavigationBar: FloatingTabBar(
        currentIndex: index,
        items: _items,
        onTap: (i) {
          widget.navigationShell.goBranch(
            i,
            initialLocation: i == widget.navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
