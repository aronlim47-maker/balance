// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:balance/app.dart';
import 'package:balance/features/today/today_screen.dart';

void main() {
  testWidgets('Balance opens the Today page', (WidgetTester tester) async {
    await tester.pumpWidget(const BalanceApp());
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
    // Capacity and the plan verdict come first; the core sections below,
    // including the five-dimension overview, start open.
    expect(find.text('TIME CAPACITY'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('WORKLOAD OVERVIEW'), 300);
    expect(find.text('WORKLOAD OVERVIEW'), findsOneWidget);
    expect(find.byTooltip('Hide Workload'), findsOneWidget);
    // Optional updates stay folded away.
    await tester.scrollUntilVisible(
      find.byTooltip('Show Optional updates'),
      300,
    );
    expect(find.byTooltip('Show Optional updates'), findsOneWidget);
  });
}
