import 'package:balance/domain/usecases/explain_no_feasible_plan.dart';
import 'package:balance/features/council/no_plan_explanation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    NoPlanExplanation explanation, {
    VoidCallback? onOpenTasks,
    VoidCallback? onOpenToday,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NoPlanExplanationCard(
            explanation: explanation,
            onOpenTasks: onOpenTasks ?? () {},
            onOpenToday: onOpenToday ?? () {},
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
            NoPlanReasonKind.flexibleUnscheduled,
            '"Lab report" (50 min) has no time on this day.',
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
    expect(find.textContaining('Nothing changes unless you confirm'), findsOneWidget);

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
}
