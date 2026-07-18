import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/crew/crew_screen.dart';
import 'features/home/home_screen.dart';
import 'features/my/my_screen.dart';
import 'features/record/record_screen.dart';
import 'features/shop/shop_screen.dart';
import 'shared/widgets/main_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// 하단 탭 5개를 StatefulShellRoute로 구성. 각 탭이 독립 네비게이터를 갖고
/// IndexedStack으로 상태를 유지한다.
final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/record', builder: (_, _) => const RecordScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/my', builder: (_, _) => const MyScreen()),
        ]),
      ],
    ),
  ],
);
