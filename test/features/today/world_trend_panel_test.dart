import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:balance/features/today/world_status_card.dart';
import 'package:balance/features/today/world_trend_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Sunday 4 October 2026: the window is Mon 28 Sep - Sun 4 Oct.
  final day = DateTime(2026, 10, 4);

  Future<void> pump(
    WidgetTester tester, {
    required List<int?> previous,
    required int? today,
    bool partial = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorldTrendPanel(
            selectedDay: day,
            previousTotals: previous,
            todayTotal: today,
            todayIsPartial: partial,
          ),
        ),
      ),
    ),
  );

  testWidgets('shows the period, the unit and seven labelled days', (
    tester,
  ) async {
    await pump(
      tester,
      previous: const [null, null, null, null, 30, null, 40],
      today: 50,
    );
    expect(find.text('7-DAY WORKLOAD TREND'), findsOneWidget);
    expect(find.textContaining('28 Sep – 4 Oct · score 0–100'), findsOneWidget);
    for (final weekday in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(weekday), findsOneWidget, reason: weekday);
    }
  });

  testWidgets('no data is No data, not an improving or zero trend', (
    tester,
  ) async {
    await pump(tester, previous: List.filled(7, null), today: null);
    expect(find.textContaining('No data in this period'), findsOneWidget);
    expect(find.textContaining('Cumulative load'), findsNothing);
    expect(find.textContaining('average'), findsNothing);
    expect(find.textContaining('(0 of 3 so far)'), findsOneWidget);
  });

  testWidgets('fewer than three recorded days shows progress, not empty bars', (
    tester,
  ) async {
    await pump(tester, previous: List.filled(7, null), today: 16);
    expect(find.text('No data'), findsNothing);
    expect(
      find.text('The chart appears after 3 days of records (1 of 3 so far).'),
      findsOneWidget,
    );
    expect(find.textContaining('Cumulative load: 16 points'), findsOneWidget);
  });

  testWidgets('three recorded days draw the bars and mark gaps as No data', (
    tester,
  ) async {
    await pump(
      tester,
      previous: const [null, null, null, null, 30, null, 40],
      today: 50,
    );
    expect(find.text('No data'), findsNWidgets(4));
    expect(find.textContaining('appears after'), findsNothing);
  });

  testWidgets('missing days are listed and left out of the average', (
    tester,
  ) async {
    // Window days Mon..Sun = previous[1..6] then today.
    await pump(
      tester,
      previous: const [null, null, 40, null, 60, null, 20],
      today: 80,
    );
    expect(
      find.text('Cumulative load: 200 points over 4 of 7 days · average 50'),
      findsOneWidget,
    );
    expect(
      find.text('3 days have no data and are left out of the average.'),
      findsOneWidget,
    );
  });

  testWidgets('a recorded zero is counted, an absent day is not', (
    tester,
  ) async {
    await pump(
      tester,
      previous: const [null, null, null, null, null, null, 0],
      today: 60,
    );
    expect(
      find.text('Cumulative load: 60 points over 2 of 7 days · average 30'),
      findsOneWidget,
    );
    expect(
      find.text('5 days have no data and are left out of the average.'),
      findsOneWidget,
    );
  });

  testWidgets('one missing day uses the singular wording', (tester) async {
    await pump(
      tester,
      previous: const [null, 10, 20, 30, 40, 50, 60],
      today: 70,
    );
    expect(
      find.text('Cumulative load: 280 points over 7 of 7 days · average 40'),
      findsOneWidget,
    );
    expect(find.textContaining('no data and'), findsNothing);
    await pump(
      tester,
      previous: const [null, null, 20, 30, 40, 50, 60],
      today: 70,
    );
    expect(
      find.text('1 day has no data and is left out of the average.'),
      findsOneWidget,
    );
  });

  testWidgets('an unknown today does not hide earlier days', (tester) async {
    await pump(
      tester,
      previous: const [null, null, null, 30, null, null, 50],
      today: null,
    );
    expect(
      find.text('Cumulative load: 80 points over 2 of 7 days · average 40'),
      findsOneWidget,
    );
  });

  testWidgets('a history list of the wrong length is treated as no data', (
    tester,
  ) async {
    await pump(tester, previous: const [10, 20], today: null);
    expect(find.textContaining('No data in this period'), findsOneWidget);
  });

  testWidgets('the card shows the panel only when history is supplied', (
    tester,
  ) async {
    final status = const WorldStatusCalculator().calculate(
      WorldStatusInput(
        localDate: day,
        windowStart: day,
        previousSevenTotals: const [null, null, null, null, null, null, null],
        plannedMinutes: 60,
        availableMinutes: 120,
      ),
    );
    Widget card({bool withHistory = false}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorldStatusCard(
            plannedMinutes: 60,
            availableMinutes: 120,
            status: status,
            selectedDay: withHistory ? day : null,
            previousTotals: withHistory ? List.filled(7, null) : null,
          ),
        ),
      ),
    );
    await tester.pumpWidget(card());
    expect(find.text('7-DAY WORKLOAD TREND'), findsNothing);
    await tester.pumpWidget(card(withHistory: true));
    expect(find.text('7-DAY WORKLOAD TREND'), findsOneWidget);
  });
}
