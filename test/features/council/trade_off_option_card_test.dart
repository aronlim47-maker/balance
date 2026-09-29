import 'package:balance/features/council/trade_off_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a suggestion explains its effects without claiming recovery', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradeOffOptionCard(
            title: 'Move reading to Thursday',
            description: 'Move 90 minutes before the deadline.',
            movedMinutes: 90,
            recoveryMinutes: 0,
            protectedSummary: 'Protected work stays unchanged.',
            costSummary: '90 min added on Thursday.',
            roomSummary: '90 min moved from today. Recovery is not reserved.',
            reviewSummary: 'Check the proposed time.',
            isSelected: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('See trade-offs'), findsOneWidget);
    expect(find.text('Protected'), findsNothing);
    await tester.tap(find.text('See trade-offs'));
    await tester.pumpAndSettle();
    for (final label in [
      'Protected',
      'Cost',
      'Room created',
      'Check before confirming',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Recovery is not reserved'), findsOneWidget);
    expect(find.textContaining('recovery protected'), findsNothing);
  });
}
