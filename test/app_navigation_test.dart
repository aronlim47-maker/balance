import 'package:balance/app.dart';
import 'package:balance/features/council/war_council_screen.dart';
import 'package:balance/features/journey/journey_screen.dart';
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
    expect(
      find.textContaining('Nothing moves until confirmed'),
      findsOneWidget,
    );
    await tester.tap(returnButton);
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });
}

