import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../router/app_router.dart';
import '../../features/auth/auth_view_model.dart';

class BalanceScaffold extends StatelessWidget {
  const BalanceScaffold({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.body,
    this.actions,
  });

  final String title;
  final int currentIndex;
  final Widget body;
  final List<Widget>? actions;

  static const _routes = [
    AppRoutes.today,
    AppRoutes.quests,
    AppRoutes.council,
    AppRoutes.sanctuary,
    AppRoutes.journey,
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        ...?actions,
        Consumer<AuthViewModel>(
          builder: (context, auth, _) {
            if (!auth.isConfigured) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: auth.currentUserEmail ?? '账户',
              onSelected: (value) {
                if (value == 'signOut') auth.signOut();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(auth.currentUserEmail ?? '已登录'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'signOut', child: Text('退出登录')),
              ],
            );
          },
        ),
      ],
    ),
    body: SafeArea(child: body),
    bottomNavigationBar: NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => context.go(_routes[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.task_alt_outlined),
          selectedIcon: Icon(Icons.task_alt),
          label: 'Quests',
        ),
        NavigationDestination(
          icon: Icon(Icons.balance_outlined),
          selectedIcon: Icon(Icons.balance),
          label: 'Council',
        ),
        NavigationDestination(
          icon: Icon(Icons.spa_outlined),
          selectedIcon: Icon(Icons.spa),
          label: 'Sanctuary',
        ),
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route),
          label: 'Journey',
        ),
      ],
    ),
  );
}
