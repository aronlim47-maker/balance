import 'package:balance/features/quests/task_form_screen.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/enums/load_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('overdue task opens its date picker without an assertion', (
    tester,
  ) async {
    final task = TaskItem(
      id: 'old',
      title: 'Overdue report',
      estimatedMinutes: 60,
      dueAt: DateTime.now().subtract(const Duration(days: 5)),
      loadCategory: LoadCategory.study,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TaskFormScreen(task: task)),
      ),
    );
    await tester.tap(find.text('Due date and time'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reducing unallocated duration saves matching remaining minutes',
    (tester) async {
      TaskItem? saved;
      final task = TaskItem(
        id: 'one',
        title: 'Report',
        estimatedMinutes: 120,
        remainingMinutes: 120,
        dueAt: DateTime.now().add(const Duration(days: 2)),
        loadCategory: LoadCategory.study,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  saved = await showModalBottomSheet<TaskItem>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TaskFormScreen(task: task),
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Estimated minutes'),
        '60',
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Save changes'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.widgetWithText(FilledButton, 'Save changes')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Save changes').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(saved?.estimatedMinutes, 60);
      expect(saved?.remainingMinutes, 60);
    },
  );

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
