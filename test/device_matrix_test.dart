import 'package:balance/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every main page, Profile, the beginner guide and the task form lay out on
/// small phones, large phones, foldables and tablets in both orientations.
/// Sizes are logical pixels (dp), the unit Android and Flutter lay out in.
const _devices = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'compact Android 360x640': Size(360, 640),
  'Galaxy A55 384x832': Size(384, 832),
  'large phone 430x932': Size(430, 932),
  'phone landscape 852x393': Size(852, 393),
  'foldable open 673x841': Size(673, 841),
  'tablet portrait 800x1280': Size(800, 1280),
  'tablet landscape 1280x800': Size(1280, 800),
};

const _pages = ['Today', 'Quests', 'Council', 'Sanctuary', 'Journey'];

/// Taps a main page in the bottom bar (phones) or the side rail (tablets).
Future<void> _open(WidgetTester tester, String page) async {
  final target = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data != null &&
        widget.data!.toLowerCase() == page.toLowerCase(),
  );
  await tester.tap(target.last);
  await tester.pumpAndSettle();
}

/// Scrolls the page to its end so every section is built and laid out.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await tester.drag(
      scrollables.first,
      const Offset(0, -600),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }
}

/// Scrolls the page back to its start.
Future<void> _scrollToTop(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  for (var i = 0; i < 6; i++) {
    await tester.drag(
      scrollables.first,
      const Offset(0, 600),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }
}

/// Brings [finder] into the middle of the screen, clear of the top bar and
/// bottom navigation, then taps it.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  _devices.forEach((name, size) {
    testWidgets('$name: every page lays out without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const BalanceApp());
      await tester.pumpAndSettle();

      // Tablets (840 dp and wider) get the side rail; phones the bottom bar.
      final wide = size.width >= 840;
      expect(find.byType(NavigationRail), wide ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationBar), wide ? findsNothing : findsOneWidget);

      for (final page in _pages) {
        await _open(tester, page);
        await _scrollToEnd(tester);
        expect(tester.takeException(), isNull, reason: '$page on $name');
      }

      // Task form (bottom sheet) on Quests.
      await _open(tester, 'Quests');
      await _scrollToTop(tester);
      // An empty board offers Create task; a board with tasks, Add task.
      await _tapVisible(
        tester,
        find
            .byWidgetPredicate(
              (w) =>
                  w is Text &&
                  (w.data == 'Create task' || w.data == 'Add task'),
            )
            .first,
      );
      expect(find.text('New task'), findsOneWidget);
      await _scrollToEnd(tester);
      expect(tester.takeException(), isNull, reason: 'task form on $name');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      // Profile and the five-step beginner guide.
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await _scrollToEnd(tester);
      expect(tester.takeException(), isNull, reason: 'Profile on $name');
      await _scrollToTop(tester);
      await _tapVisible(tester, find.text('Beginner guide'));
      for (var step = 0; step < 4; step++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'guide step ${step + 2} on $name',
        );
      }
      expect(find.text('Get started'), findsOneWidget);
    });
  });
}
