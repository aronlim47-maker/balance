import 'package:flutter/widgets.dart';

import 'theme_controller.dart';

/// Makes the [ThemeController] available to the widget tree.
///
/// Widgets that call [ThemeScope.maybeOf] rebuild when the look changes.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller, or null when the widget is shown without one
  /// (for example in a widget test that pumps a single screen).
  static ThemeController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()?.notifier;
}

/// Repaints every screen in place when the look changes.
///
/// Most widgets read colours from `BalanceColors`, which does not register a
/// dependency on the theme. When the controller changes, this marks every
/// widget below it for rebuild, the same way hot reload does. Widgets keep
/// their state, so the current page, the navigation stack, open dialogs and
/// text typed into forms all stay as they were.
class ThemeRefresh extends StatefulWidget {
  const ThemeRefresh({
    super.key,
    required this.controller,
    required this.child,
  });

  final ThemeController controller;
  final Widget child;

  @override
  State<ThemeRefresh> createState() => _ThemeRefreshState();
}

class _ThemeRefreshState extends State<ThemeRefresh> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuildAll);
  }

  @override
  void didUpdateWidget(ThemeRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuildAll);
      widget.controller.addListener(_rebuildAll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuildAll);
    super.dispose();
  }

  void _rebuildAll() {
    if (!mounted) return;
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
