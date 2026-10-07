import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/balance_colors.dart';
import '../../features/auth/auth_view_model.dart';
import 'rpg_widgets.dart';

/// Shared page shell: RPG header + bottom navigation.
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BalanceColors.background,
    body: SafeArea(
      bottom: false,
      child: Column(
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
      ),
    ),
    bottomNavigationBar: _RpgNavigationBar(
      currentIndex: currentIndex,
      onSelected: (index) => context.go(_routes[index]),
    ),
  );
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Semantics(header: true, child: RpgHeadline(headline))),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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

class _NavItem {
  const _NavItem(this.label, this.build);
  final String label;
  final Widget Function(bool selected, Color color) build;
}

class _RpgNavigationBar extends StatelessWidget {
  const _RpgNavigationBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static final _items = <_NavItem>[
    _NavItem(
      'Today',
          (selected, color) =>
          DiamondIcon(size: 20, filled: false, color: color, strokeWidth: 1.6),
    ),
    _NavItem(
      'Quests',
          (selected, color) => Icon(Icons.notes_rounded, size: 22, color: color),
    ),
    _NavItem(
      'Council',
          (selected, color) => DiamondIcon(size: 20, filled: true, color: color),
    ),
    _NavItem(
      'Sanctuary',
          (selected, color) => Icon(Icons.eco_outlined, size: 21, color: color),
    ),
    _NavItem(
      'Journey',
          (selected, color) =>
          Icon(Icons.bar_chart_rounded, size: 22, color: color),
    ),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: BalanceColors.surfaceSunken,
      border: Border(top: BorderSide(color: BalanceColors.outline)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavButton(
                  item: _items[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BalanceColors.accentBright : BalanceColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            item.build(selected, color),
            const SizedBox(height: 6),
            Text(
              item.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
                letterSpacing: 1.2,
                color: selected ? BalanceColors.text : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
