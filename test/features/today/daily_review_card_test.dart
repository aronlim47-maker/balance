import 'package:balance/domain/models/check_in.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/today/daily_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Daily Review can be skipped without writing a record', (
    tester,
  ) async {
    CheckIn? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async =>
                  saved = await showModalBottomSheet<CheckIn>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        DailyReviewSheet(date: DateTime(2026, 9, 30)),
                  ),
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
  });

  testWidgets('Daily Review saves an explicit mental energy choice', (
    tester,
  ) async {
    CheckIn? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async =>
                  saved = await showModalBottomSheet<CheckIn>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        DailyReviewSheet(date: DateTime(2026, 9, 30)),
                  ),
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    // Mental energy is the first group of energy rows.
    await tester.tap(find.text('Moderate').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(saved?.mentalEnergyLevel, EnergyLevel.moderate);
    expect(saved?.physicalEnergyLevel, isNull);
  });
}
