import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import '../l10n/tr.dart';

/// Sun/moon button that switches Balance between dark and light in one tap.
///
/// The icon shows the look it switches TO: a sun in dark mode ("Switch to
/// light mode") and a moon in light mode ("Switch to dark mode"). The same
/// words are the tooltip and the TalkBack label.
///
/// Shows nothing when no [ThemeScope] is above it (single-screen tests).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  static final toLightLabel = 'Switch to light mode'.tr;
  static final toDarkLabel = 'Switch to dark mode'.tr;

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final dark = controller.isDark;
    return IconButton(
      tooltip: dark ? toLightLabel : toDarkLabel,
      onPressed: controller.toggle,
      icon: AnimatedSwitcher(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(dark),
        ),
      ),
    );
  }
}
