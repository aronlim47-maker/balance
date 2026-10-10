import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/balance_colors.dart';
import '../../features/auth/auth_view_model.dart';
import 'rpg_widgets.dart';

/// Shared page shell: RPG header + responsive navigation.
///
/// Phones (< 840 px wide) get a bottom [NavigationBar]; wider screens get a
/// [NavigationRail] sidebar with the content centred (max 1100 px).
///
/// [title] is the small eyebrow line (e.g. "Quest Board"); [headline] is the
/// large title under it (e.g. "Quest Log"). When [headline] is omitted the
/// [title] is shown as the large title instead.
class BalanceScaffold extends StatelessWidget {
  const BalanceScaffold({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.body,
    this.actions,
    this.headline,
    this.subtitle,
    this.headerTrailing,
    this.eyebrowTone = RpgTone.accent,
  });

  final String title;
  final int currentIndex;
  final Widget body;
  final List<Widget>? actions;
  final String? headline;
  final String? subtitle;

  /// Optional widget shown to the right of the headline (e.g. a status tag).
  final Widget? headerTrailing;
  final RpgTone eyebrowTone;

  static const _routes = [
    AppRoutes.today,
    AppRoutes.quests,
    AppRoutes.council,
    AppRoutes.sanctuary,
    AppRoutes.journey,
  ];

  static const _labels = ['Today', 'Quests', 'Council', 'Sanctuary', 'Journey'];

  static Widget _icon(int index, {required bool selected}) {
    final color = selected
        ? BalanceColors.accentBright
        : BalanceColors.textMuted;
    return switch (index) {
      0 => DiamondIcon(size: 20, color: color, strokeWidth: 1.6),
      1 => Icon(Icons.notes_rounded, size: 22, color: color),
      2 => DiamondIcon(size: 20, filled: true, color: color),
      3 => Icon(Icons.eco_outlined, size: 21, color: color),
      _ => Icon(Icons.bar_chart_rounded, size: 22, color: color),
    };
  }

  static const _navLabelStyle = TextStyle(
    fontFamily: AppTheme.displayFont,
    fontWeight: FontWeight.w700,
    fontSize: 11.5,
    letterSpacing: 0.8,
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          eyebrow: headline == null ? null : title,
          headline: headline ?? title,
          subtitle: subtitle,
          trailing: headerTrailing,
          tone: eyebrowTone,
          actions: [
            ...?actions,
            IconButton(
              tooltip: 'Profile',
              onPressed: () => context.push(AppRoutes.profile),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
        ),
        Consumer<AuthViewModel>(
          builder: (context, auth, _) => auth.isConfigured
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: BalanceColors.warningBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: BalanceColors.warningBorder),
                  ),
                  child: const Text(
                    'Local preview · Changes are not saved to Supabase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BalanceColors.warning,
                      fontSize: 13,
                    ),
                  ),
                ),
        ),
        Expanded(child: body),
      ],
    );

    // Tabs are switched with context.go, so there is no route below a tab:
    // Android back on any tab except Today returns to Today instead of
    // closing the app.
    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(_routes[0]);
      },
      child: Scaffold(
        backgroundColor: BalanceColors.background,
        body: SafeArea(
          bottom: wide,
          child: wide
              ? Row(
                  children: [
                    NavigationRailTheme(
                      data: NavigationRailThemeData(
                        backgroundColor: BalanceColors.surfaceSunken,
                        indicatorColor: BalanceColors.accentDim,
                        indicatorShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        selectedLabelTextStyle: _navLabelStyle.copyWith(
                          color: BalanceColors.text,
                        ),
                        unselectedLabelTextStyle: _navLabelStyle.copyWith(
                          color: BalanceColors.textMuted,
                        ),
                      ),
                      child: NavigationRail(
                        selectedIndex: currentIndex,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: (index) =>
                            context.go(_routes[index]),
                        destinations: [
                          for (var i = 0; i < _labels.length; i++)
                            NavigationRailDestination(
                              icon: _icon(i, selected: false),
                              selectedIcon: _icon(i, selected: true),
                              label: Text(_labels[i]),
                            ),
                        ],
                      ),
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
            : NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: BalanceColors.surfaceSunken,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: BalanceColors.accentDim,
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  height: 68,
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => _navLabelStyle.copyWith(
                      color: states.contains(WidgetState.selected)
                          ? BalanceColors.text
                          : BalanceColors.textMuted,
                    ),
                  ),
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: BalanceColors.outline),
                    ),
                  ),
                  child: MediaQuery.withClampedTextScaling(
                    // Bottom-bar labels stay on one line at large text sizes.
                    // Page content still scales with the phone's font setting.
                    maxScaleFactor: 1.0,
                    child: NavigationBar(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (index) =>
                          context.go(_routes[index]),
                      destinations: [
                        for (var i = 0; i < _labels.length; i++)
                          NavigationDestination(
                            icon: _icon(i, selected: false),
                            selectedIcon: _icon(i, selected: true),
                            label: _labels[i].toUpperCase(),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.eyebrow,
    required this.headline,
    required this.subtitle,
    required this.trailing,
    required this.tone,
    required this.actions,
  });

  final String? eyebrow;
  final String headline;
  final String? subtitle;
  final Widget? trailing;
  final RpgTone tone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: eyebrow == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Eyebrow(eyebrow!, tone: tone),
                    ),
            ),
            ...actions,
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: RpgHeadline(headline)),
              ),
              ?trailing,
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: BalanceColors.textMuted,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
