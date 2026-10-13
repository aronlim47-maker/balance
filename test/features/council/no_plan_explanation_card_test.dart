import 'package:balance/domain/usecases/explain_no_feasible_plan.dart';
import 'package:balance/domain/usecases/suggest_free_time.dart';
import 'package:balance/features/council/no_plan_explanation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    NoPlanExplanation explanation, {
    VoidCallback? onOpenTasks,
    VoidCallback? onOpenToday,
    FreeTimeSuggestion? freeTime,
    ValueChanged<String>? onEditTask,
    ValueChanged<DateTime>? onAddFreeTimeOn,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NoPlanExplanationCard(
            explanation: explanation,
            onOpenTasks: onOpenTasks ?? () {},
            onOpenToday: onOpenToday ?? () {},
            freeTime: freeTime,
            onEditTask: onEditTask,
            onAddFreeTimeOn: onAddFreeTimeOn,
          ),
        ),
      ),
    ),
  );

  testWidgets('lists every reason and offers both next steps', (tester) async {
    var openedTasks = 0;
    var openedToday = 0;
    await pumpCard(
      tester,
      const NoPlanExplanation(
        gapMinutes: 230,
        extraWorkMinutes: 40,
        dueBeforeFreeTimeMinutes: 190,
        reasons: [
          NoPlanReason(
            NoPlanReasonKind.dueBeforeFreeTime,
            '190 min of work is due before your free time starts (7:00 PM).',
          ),
          NoPlanReason(
            NoPlanReasonKind.noOtherDay,
            '"Lab report" (50 min) is due on this day.',
            taskId: 'lab',
          ),
          NoPlanReason(
            NoPlanReasonKind.protectedStays,
            '"Thesis" (230 min) is protected, so it stays where it is.',
            taskId: 'thesis',
          ),
        ],
      ),
      onOpenTasks: () => openedTasks++,
      onOpenToday: () => openedToday++,
    );

    expect(find.text('No safe move found'), findsOneWidget);
    expect(find.textContaining('190 min of work'), findsOneWidget);
    expect(find.textContaining('"Lab report" (50 min)'), findsOneWidget);
    expect(find.textContaining('"Thesis" (230 min)'), findsOneWidget);
    expect(
      find.textContaining('Nothing changes unless you confirm'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Review tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review tasks'));
    await tester.ensureVisible(find.text('Add free time on Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add free time on Today'));
    expect(openedTasks, 1);
    expect(openedToday, 1);
  });

  testWidgets('shows only the step that helps', (tester) async {
    await pumpCard(
      tester,
      const NoPlanExplanation(
        gapMinutes: 60,
        extraWorkMinutes: 60,
        dueBeforeFreeTimeMinutes: 0,
        reasons: [
          NoPlanReason(
            NoPlanReasonKind.noFreeTime,
            'No free time is added for this day.',
          ),
        ],
      ),
    );

    expect(find.text('Add free time on Today'), findsOneWidget);
    expect(find.text('Review tasks'), findsNothing);
  });

  testWidgets('Edit task opens the named task; free time names a day', (
    tester,
  ) async {
    final edited = <String>[];
    final days = <DateTime>[];
    await pumpCard(
      tester,
      const NoPlanExplanation(
        gapMinutes: 60,
        extraWorkMinutes: 60,
        dueBeforeFreeTimeMinutes: 0,
        reasons: [
          NoPlanReason(
            NoPlanReasonKind.noOtherDay,
            '"Essay" (60 min) is due on this day.',
            taskId: 'essay',
          ),
          NoPlanReason(
            NoPlanReasonKind.noLaterFreeTime,
            'No free time was found for "Report".',
            taskId: 'report',
          ),
          NoPlanReason(
            NoPlanReasonKind.protectedStays,
            '"Shift" is protected.',
            taskId: 'shift',
          ),
        ],
      ),
      freeTime: FreeTimeSuggestion(
        day: DateTime(2026, 10, 14),
        minutes: 90,
        taskTitle: 'Report',
        start: DateTime(2026, 10, 14, 8),
        end: DateTime(2026, 10, 14, 9, 30),
      ),
      onEditTask: edited.add,
      onAddFreeTimeOn: days.add,
    );

    // Only the task whose own details can unblock it gets Edit task.
    expect(find.text('Edit task'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit task'));
    await tester.tap(find.text('Edit task'));
    expect(edited, ['essay']);

    expect(
      find.textContaining('Add 1h 30m of free time on Wed 14 Oct'),
      findsOneWidget,
    );
    expect(find.textContaining('8:00'), findsOneWidget);
    expect(find.textContaining('"Report" there'), findsOneWidget);
    await tester.ensureVisible(find.text('Add free time on Wed 14 Oct'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add free time on Wed 14 Oct'));
    expect(days, [DateTime(2026, 10, 14)]);
    // The specific day replaces the generic Today button.
    expect(find.text('Add free time on Today'), findsNothing);
    expect(find.textContaining('already'), findsNothing);
  });

  testWidgets('says when the suggested day is already over', (tester) async {
    await pumpCard(
      tester,
      const NoPlanExplanation(
        gapMinutes: 20,
        extraWorkMinutes: 20,
        dueBeforeFreeTimeMinutes: 0,
        reasons: [
          NoPlanReason(NoPlanReasonKind.noLaterFreeTime, 'No free time.'),
        ],
      ),
      freeTime: FreeTimeSuggestion(
        day: DateTime(2026, 10, 14),
        minutes: 150,
        taskTitle: 'T1',
        start: DateTime(2026, 10, 14, 8),
        end: DateTime(2026, 10, 14, 10, 30),
        dayAlreadyOverMinutes: 120,
      ),
      onAddFreeTimeOn: (_) {},
    );
    expect(
      find.textContaining('Wed 14 Oct is already 2h over'),
      findsOneWidget,
    );
  });
}
