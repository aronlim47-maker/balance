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
    // Capacity and the plan verdict come first and start open; the overview
    // follows below in a section that opens with its + button.
    expect(find.text('TIME CAPACITY'), findsOneWidget);
    expect(find.text('WORKLOAD OVERVIEW'), findsNothing);
    await tester.scrollUntilVisible(find.byTooltip('Show Workload'), 300);
    await tester.tap(find.byTooltip('Show Workload'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('WORKLOAD OVERVIEW'), 300);
    expect(find.text('WORKLOAD OVERVIEW'), findsOneWidget);
  });
}
