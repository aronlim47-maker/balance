import 'package:balance/app.dart';
import 'package:balance/core/shared_widgets/theme_toggle_button.dart';
import 'package:balance/core/theme/balance_colors.dart';
import 'package:balance/core/theme/balance_palette.dart';
import 'package:balance/core/theme/theme_controller.dart';
import 'package:balance/core/theme/theme_scope.dart';
import 'package:balance/features/quests/task_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

Color? _pageBackground(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  // Other test files expect the default dark palette.
  tearDown(() => BalanceColors.use(BalancePalette.dark));

  group('ThemeController', () {
    test('starts in dark mode when nothing is saved', () async {
      final controller = await ThemeController.load();
      expect(controller.isDark, isTrue);
      expect(BalanceColors.active, BalancePalette.dark);
    });

    test('restores a saved light choice', () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.storageKey: 'light',
      });
      final controller = await ThemeController.load();
      expect(controller.mode, ThemeMode.light);
      expect(BalanceColors.background, BalancePalette.light.background);
    });

    test('toggle switches the colours and saves the choice', () async {
      final controller = await ThemeController.load();
      await controller.toggle();
      expect(controller.isDark, isFalse);
      expect(BalanceColors.text, BalancePalette.light.text);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.storageKey), 'light');

      await controller.toggle();
      expect(controller.isDark, isTrue);
      expect(prefs.getString(ThemeController.storageKey), 'dark');
    });
  });

  testWidgets('one tap switches the whole app and back', (tester) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    expect(_brightness(tester), Brightness.dark);
    expect(_pageBackground(tester), BalancePalette.dark.background);
    expect(find.byTooltip(ThemeToggleButton.toLightLabel), findsOneWidget);

    await tester.tap(find.byTooltip(ThemeToggleButton.toLightLabel));
    await tester.pumpAndSettle();

    expect(_brightness(tester), Brightness.light);
    // Widgets that read BalanceColors directly were rebuilt too.
    expect(_pageBackground(tester), BalancePalette.light.background);
    expect(find.byTooltip(ThemeToggleButton.toDarkLabel), findsOneWidget);

    await tester.tap(find.byTooltip(ThemeToggleButton.toDarkLabel));
    await tester.pumpAndSettle();
    expect(_brightness(tester), Brightness.dark);
    expect(_pageBackground(tester), BalancePalette.dark.background);
  });

  testWidgets('switching keeps the open form and typed text', (tester) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('QUESTS').last);
    await tester.pumpAndSettle();

    // Open the New task form on top of Quests and type a title. With no
    // tasks yet, Quests shows its Create task button.
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskFormScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Revise finals');
    await tester.pumpAndSettle();

    // Switch the look while the form is open.
    final controller = ThemeScope.maybeOf(
      tester.element(find.byType(TaskFormScreen)),
    )!;
    await controller.toggle();
    await tester.pumpAndSettle();

    expect(_brightness(tester), Brightness.light);
    expect(find.byType(TaskFormScreen), findsOneWidget);
    expect(find.text('Revise finals'), findsOneWidget);
  });

  for (final tab in ['TODAY', 'QUESTS', 'COUNCIL', 'SANCTUARY', 'JOURNEY']) {
    testWidgets('$tab text is readable in light mode', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        BalanceApp(themeController: ThemeController(mode: ThemeMode.light)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();

      expect(_brightness(tester), Brightness.light);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }
}
