import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/balance_colors.dart';
import '../../features/auth/auth_view_model.dart';
import 'collapsible_section.dart';
import 'rpg_widgets.dart';
import 'sound_toggle_button.dart';
import 'theme_toggle_button.dart';
import '../l10n/tr.dart';

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
    this.help,
    this.headerTrailing,
    this.eyebrowTone = RpgTone.accent,
  });

  final String title;
  final int currentIndex;
  final Widget body;
  final List<Widget>? actions;
  final String? headline;
  final String? subtitle;

  /// What the page is for, in grey. Hidden behind a ? button next to the
  /// headline until the user taps it.
  final String? help;

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

  static List<String> get _labels => [
    'Today',
    'Quests'.tr,
    'Council'.tr,
    'Sanctuary'.tr,
    'Journey'.tr,
  ];

  static Widget _icon(int index, {required bool selected}) {
    final color = selected
        ? BalanceColors.accentBright
        : BalanceColors.textMuted;
    // RPG landmarks: the world, the quest book, the council keep, the
    // campfire and the compass.
    final icon = switch (index) {
      0 => selected ? Icons.public : Icons.public_outlined,
      1 => selected ? Icons.auto_stories : Icons.auto_stories_outlined,
      2 => selected ? Icons.castle : Icons.castle_outlined,
      3 =>
        selected
            ? Icons.local_fire_department
            : Icons.local_fire_department_outlined,
      _ => selected ? Icons.explore : Icons.explore_outlined,
    };
    return Icon(icon, size: 22, color: color);
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
          help: help,
          trailing: headerTrailing,
          tone: eyebrowTone,
          actions: [
            ...?actions,
            // Same place on every page: just left of Profile.
            const SoundToggleButton(),
            const ThemeToggleButton(),
            IconButton(
              tooltip: 'Profile'.tr,
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
                  child: Text(
                    'Local preview · Changes are not saved to Supabase'.tr,
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
        body: DecoratedBox(
          // Faint torchlight glow from the top of the page.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.15),
              radius: 1.1,
              colors: [
                // Violet torchlight at night, warm candlelight on parchment.
                BalanceColors.isDark
                    ? BalanceColors.accentDim.withValues(alpha: 0.55)
                    : BalanceColors.goldGlow.withValues(alpha: 0.3),
                BalanceColors.background.withValues(alpha: 0),
              ],
            ),
          ),
          child: SafeArea(
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
                  decoration: BoxDecoration(
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

class _Header extends StatefulWidget {
  const _Header({
    required this.eyebrow,
    required this.headline,
    required this.subtitle,
    required this.help,
    required this.trailing,
    required this.tone,
    required this.actions,
  });

  final String? eyebrow;
  final String headline;
  final String? subtitle;
  final String? help;
  final Widget? trailing;
  final RpgTone tone;
  final List<Widget> actions;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _showHelp = false;

  @override
  Widget build(BuildContext context) {
    final grey = TextStyle(
      color: BalanceColors.textMuted,
      fontSize: 15,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: widget.eyebrow == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Eyebrow(widget.eyebrow!, tone: widget.tone),
                      ),
              ),
              ...widget.actions,
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            // Wrap, not Row: at large text sizes the status badge moves
            // below the headline instead of overflowing.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: RpgHeadline(widget.headline),
                      ),
                    ),
                    if (widget.help != null)
                      HelpButton(
                        topic: 'this page'.tr,
                        showing: _showHelp,
                        onPressed: () => setState(() => _showHelp = !_showHelp),
                      ),
                  ],
                ),
                ?widget.trailing,
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 12),
            child: RpgOrnament(),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(widget.subtitle!, style: grey),
            ),
          ],
          if (widget.help != null && _showHelp) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(widget.help!, style: grey),
            ),
          ],
        ],
      ),
    );
  }
}
