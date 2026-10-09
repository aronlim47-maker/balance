import 'package:balance/features/today/social_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('social card keeps controls collapsed by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialCard(
            events: const [],
            noCommitments: false,
            isSaving: false,
            onAdd: () {},
            onDelete: (_) {},
            onNoCommitmentsChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Not recorded'), findsOneWidget);
    expect(find.text('Add event'), findsNothing);
    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();
    expect(find.text('Add event'), findsOneWidget);
  });

  testWidgets('social event requires duration and an explicit pressure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SocialEventSheet(day: DateTime(2026, 9, 27))),
      ),
    );
    await tester.tap(find.text('Save event'));
    await tester.pump();
    expect(find.textContaining('Enter 1–720 minutes'), findsOneWidget);
  });
}
