import 'package:balance/app.dart';
import 'package:balance/features/council/plan_history_screen.dart';
import 'package:balance/features/council/war_council_screen.dart';
import 'package:balance/features/journey/journey_screen.dart';
import 'package:balance/features/journey/reflection_history_screen.dart';
import 'package:balance/features/profile/profile_screen.dart';
import 'package:balance/features/quests/quest_board_screen.dart';
import 'package:balance/features/sanctuary/sanctuary_screen.dart';
import 'package:balance/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all primary destinations remain reachable', (tester) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.textContaining('Local preview'), findsOneWidget);

    await tester.tap(find.text('QUESTS').last);
    await tester.pumpAndSettle();
    expect(find.byType(QuestBoardScreen), findsOneWidget);

    await tester.tap(find.text('COUNCIL').last);
    await tester.pumpAndSettle();
    expect(find.byType(WarCouncilScreen), findsOneWidget);

    await tester.tap(find.text('SANCTUARY').last);
    await tester.pumpAndSettle();
    expect(find.byType(SanctuaryScreen), findsOneWidget);

    await tester.tap(find.text('JOURNEY').last);
    await tester.pumpAndSettle();
    expect(find.byType(JourneyScreen), findsOneWidget);

    await tester.tap(find.text('TODAY').last);
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

    await tester.tap(find.text('COUNCIL').last);
    await tester.pumpAndSettle();
    expect(find.byType(WarCouncilScreen), findsOneWidget);
    final returnButton = find.text('Back to Today');
    await tester.scrollUntilVisible(returnButton, 250);
    // A day without overload says so plainly instead of offering plans.
    expect(
      find.text('No changes needed. Your plan fits this day.'),
      findsOneWidget,
    );
    expect(find.text('Confirm selected plan'), findsNothing);
    await tester.tap(returnButton);
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('Android back on a tab returns to Today instead of closing', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    for (final tab in ['QUESTS', 'COUNCIL', 'SANCTUARY', 'JOURNEY']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      // true = the app handled back; false would close the app.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
    }
  });

  testWidgets('Journey opens saved reflections from earlier weeks', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('JOURNEY').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My reflections'));
    await tester.pumpAndSettle();
    expect(find.byType(ReflectionHistoryScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(JourneyScreen), findsOneWidget);
  });

  testWidgets('War Council without availability does not claim On track', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('COUNCIL').last);
    await tester.pumpAndSettle();
    expect(find.text('On track'), findsNothing);
    expect(find.text('No time added'), findsOneWidget);
  });

  testWidgets('War Council opens plan history so a plan can be undone later', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('COUNCIL').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Plan history'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanHistoryScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WarCouncilScreen), findsOneWidget);
  });
}
