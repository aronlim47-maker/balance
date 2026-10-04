import 'package:balance/app.dart';
import 'package:balance/features/council/war_council_screen.dart';
import 'package:balance/features/journey/journey_screen.dart';
import 'package:balance/features/profile/profile_screen.dart';
import 'package:balance/features/quests/quest_board_screen.dart';
import 'package:balance/features/sanctuary/sanctuary_screen.dart';
import 'package:balance/features/today/today_screen.dart';
import 'package:balance/features/reminders/reminder_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Reminder settings opens safely in preview without requesting permission',
    (tester) async {
      await tester.pumpWidget(const BalanceApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Task reminders'), 250);
      await tester.tap(find.text('Task reminders'));
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSettingsScreen), findsOneWidget);
      expect(
        find.text('Sign in on Android or iOS to use device reminders.'),
        findsOneWidget,
      );
      final switches = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switches.first.value, isFalse);
      expect(switches.every((item) => item.onChanged == null), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('all primary destinations remain reachable', (tester) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.textContaining('Local preview'), findsOneWidget);

    await tester.tap(find.text('Quests').last);
    await tester.pumpAndSettle();
    expect(find.byType(QuestBoardScreen), findsOneWidget);

    await tester.tap(find.text('Council').last);
    await tester.pumpAndSettle();
    expect(find.byType(WarCouncilScreen), findsOneWidget);

    await tester.tap(find.text('Sanctuary').last);
    await tester.pumpAndSettle();
    expect(find.byType(SanctuaryScreen), findsOneWidget);

    await tester.tap(find.text('Journey').last);
    await tester.pumpAndSettle();
    expect(find.byType(JourneyScreen), findsOneWidget);

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('profile opens from the app shell and returns to Today', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('No cloud account connected'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('War Council can return to Today without confirming', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Council').last);
    await tester.pumpAndSettle();
    expect(find.byType(WarCouncilScreen), findsOneWidget);
    final returnButton = find.text('Back to Today');
    await tester.scrollUntilVisible(returnButton, 250);
    expect(
      find.textContaining('Nothing moves until confirmed'),
      findsOneWidget,
    );
    await tester.tap(returnButton);
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });
}
