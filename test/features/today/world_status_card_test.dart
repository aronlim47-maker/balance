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

    expect(find.text('WORKLOAD OVERVIEW'), findsOneWidget);
    expect(find.text('WORLD STATUS'), findsOneWidget);
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
    final timeDimension = find.textContaining('Time ·');
    await tester.ensureVisible(timeDimension);
    await tester.tap(timeDimension);
    await tester.pumpAndSettle();
    expect(find.textContaining('Capacity gap'), findsOneWidget);
    expect(
      find.textContaining('Unknown means missing information'),
      findsOneWidget,
    );
  });

  Future<void> pumpCapacity(
    WidgetTester tester, {
    required int planned,
    required int available,
  }) async {
    final status = const WorldStatusCalculator().calculate(
      WorldStatusInput(
        localDate: DateTime(2026, 10, 9),
        windowStart: DateTime(2026, 10, 9),
        previousSevenTotals: const [null, null, null, null, null, null, null],
        plannedMinutes: planned,
        availableMinutes: available,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WorldStatusCard(
              plannedMinutes: planned,
              availableMinutes: available,
              status: status,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('no time added is neutral, never a green Fits tag', (
    tester,
  ) async {
    await pumpCapacity(tester, planned: 0, available: 0);
    expect(find.text('NO TIME ADDED YET'), findsOneWidget);
    expect(find.text('NO TIME ADDED'), findsOneWidget);
    expect(find.text('FITS'), findsNothing);
    expect(find.textContaining('Fits today'), findsNothing);
  });

  testWidgets('Fits appears only when time exists and nothing is over', (
    tester,
  ) async {
    await pumpCapacity(tester, planned: 60, available: 180);
    expect(find.text('FITS'), findsOneWidget);
    expect(find.text('NO TIME ADDED'), findsNothing);
  });

  testWidgets('300 planned in 180 available shows a 2h over tag', (
    tester,
  ) async {
    await pumpCapacity(tester, planned: 300, available: 180);
    expect(find.text('FITS'), findsNothing);
    expect(find.textContaining('Beyond capacity'), findsOneWidget);
  });

  testWidgets('shows change since yesterday only where both days are known', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final status = const WorldStatusCalculator().calculate(
      WorldStatusInput(
        localDate: DateTime(2026, 9, 27),
        windowStart: DateTime(2026, 9, 27),
        previousSevenTotals: const [null, null, null, null, null, null, null],
        plannedMinutes: 120,
        availableMinutes: 60,
        unfinishedTasks: const [],
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
              changes: const {
                WorldDimension.mental: 6,
                WorldDimension.time: -4,
                WorldDimension.physical: null,
                WorldDimension.social: 0,
                WorldDimension.errands: null,
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('▲ 6'), findsOneWidget);
    expect(find.text('▼ 4'), findsOneWidget);
    expect(find.text('–'), findsOneWidget);
    expect(find.text('▲ ▼ change since yesterday'), findsOneWidget);
    expect(find.bySemanticsLabel('up 6 since yesterday'), findsOneWidget);
    expect(find.bySemanticsLabel('down 4 since yesterday'), findsOneWidget);
    semantics.dispose();
  });
}
