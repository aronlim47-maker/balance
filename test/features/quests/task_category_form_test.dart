import 'package:balance/features/quests/task_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new task requires an explicit category', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TaskFormScreen())),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Report',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Estimated minutes'),
      '60',
    );
    await tester.scrollUntilVisible(
      find.text('Create task'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create task'));
    await tester.pump();
    expect(find.text('Choose a task category before saving.'), findsOneWidget);
  });
}
