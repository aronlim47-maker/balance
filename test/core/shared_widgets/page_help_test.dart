import 'package:balance/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page descriptions are hidden behind the ? next to the title', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('COUNCIL').last);
    await tester.pumpAndSettle();

    const help = 'Safe ways to fix an overloaded day.';
    expect(find.text(help), findsNothing);

    await tester.tap(find.byTooltip('About this page'));
    await tester.pumpAndSettle();
    expect(find.text(help), findsOneWidget);

    await tester.tap(find.byTooltip('Hide info about this page'));
    await tester.pumpAndSettle();
    expect(find.text(help), findsNothing);
  });

  testWidgets('every main page has a ? and Today keeps its date visible', (
    tester,
  ) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();
    for (final tab in ['TODAY', 'QUESTS', 'COUNCIL', 'SANCTUARY', 'JOURNEY']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('About this page'), findsOneWidget, reason: tab);
    }
    await tester.tap(find.text('TODAY').last);
    await tester.pumpAndSettle();
    // The date is information, not a description, so it stays visible.
    expect(find.textContaining('day, '), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
