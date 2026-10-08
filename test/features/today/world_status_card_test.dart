import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/today/world_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows five dimensions and does not invent a total', (
    tester,
  ) async {
    final status = const WorldStatusCalculator().calculate(
      WorldStatusInput(
        localDate: DateTime(2026, 9, 27),
        windowStart: DateTime(2026, 9, 27),
        previousSevenTotals: const [null, null, null, null, null, null, null],
        plannedMinutes: 120,
        availableMinutes: 60,
        unfinishedTasks: [
          WorldStatusTask(
            remainingMinutes: 120,
            dueAt: DateTime(2026, 9, 28),
            category: null,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorldStatusCard(
              plannedMinutes: 120,
              availableMinutes: 60,
              status: status,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Workload Overview'), findsOneWidget);
    expect(find.text('World Status'), findsOneWidget);
    expect(find.text('Mental'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Physical'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Errands'), findsOneWidget);
    expect(find.text('Not enough data'), findsOneWidget);
    expect(find.textContaining('Enable movement tracking'), findsNothing);
    await tester.tap(find.text('How is this calculated?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enable movement tracking'), findsOneWidget);
    await tester.tap(find.textContaining('Time ·'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Capacity gap'), findsOneWidget);
    expect(find.textContaining('Unknown means missing information'), findsOneWidget);
  });
}
