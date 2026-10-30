import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/features/today/capacity_gap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget card) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: card),
);

void main() {
  testWidgets('a plain overload states the gap only', (tester) async {
    await tester.pumpWidget(
      _host(
        const CapacityGapCard(
          overloadMinutes: 120,
          plannedMinutes: 300,
          availableMinutes: 180,
        ),
      ),
    );
    expect(
      find.text('120 minutes must be moved, reduced or recovered.'),
      findsOneWidget,
    );
  });

  testWidgets('work due before the free time explains the larger gap', (
    tester,
  ) async {
    // Smoke test S20: 600 min due before a 300-minute free window.
    await tester.pumpWidget(
      _host(
        const CapacityGapCard(
          overloadMinutes: 600,
          plannedMinutes: 600,
          availableMinutes: 300,
        ),
      ),
    );
    expect(
      find.textContaining(
        '300 min is beyond your free time and 300 min is due before there '
        'is enough free time for it.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _host(
        const CapacityGapCard(
          overloadMinutes: 90,
          plannedMinutes: 90,
          availableMinutes: 180,
        ),
      ),
    );
    expect(
      find.textContaining(
        'All of it is due before there is enough free time for it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty day is not called balanced', (tester) async {
    await tester.pumpWidget(
      _host(
        const CapacityGapCard(
          overloadMinutes: 0,
          plannedMinutes: 0,
          availableMinutes: 0,
        ),
      ),
    );
    expect(find.text('Nothing planned yet'), findsOneWidget);
    expect(find.text('Plan is balanced'), findsNothing);

    await tester.pumpWidget(
      _host(
        const CapacityGapCard(
          overloadMinutes: 0,
          plannedMinutes: 60,
          availableMinutes: 180,
        ),
      ),
    );
    expect(find.text('Plan is balanced'), findsOneWidget);
  });
}
