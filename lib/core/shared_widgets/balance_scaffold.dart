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
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final content = Column(
      children: [
        Consumer<AuthViewModel>(
          builder: (context, auth, _) => auth.isConfigured
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Text(
                    'Local preview · Changes are not saved to Supabase',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
        Expanded(child: body),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.push(AppRoutes.profile),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: currentIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (index) =>
                        context.go(_routes[index]),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.today_outlined),
                        label: Text('Today'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.task_alt),
                        label: Text('Quests'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.balance),
                        label: Text('Council'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.spa_outlined),
                        label: Text('Sanctuary'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.route_outlined),
                        label: Text('Journey'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: content,
                      ),
                    ),
                  ),
                ],
              )
            : content,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
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
}
