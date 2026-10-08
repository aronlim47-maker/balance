import 'package:balance/domain/enums/task_flexibility.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/generate_trade_offs.dart';
import 'package:balance/domain/usecases/preview_trade_off.dart';
import 'package:balance/features/council/plan_comparison_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = DateTime(2026, 10, 5);
  final destination = DateTime(2026, 10, 6);
  TaskItem task({
    bool protected = false,
    TaskFlexibility flexibility = TaskFlexibility.flexible,
  }) => TaskItem(
    id: 'reading',
    title: 'Reading',
    estimatedMinutes: 120,
    dueAt: DateTime(2026, 10, 7),
    scheduledStart: DateTime(2026, 10, 5, 10),
    scheduledEnd: DateTime(2026, 10, 5, 12),
    isProtected: protected,
    flexibility: flexibility,
  );
  final availability = [
    AvailabilityBlock(
      id: 'today',
      startAt: DateTime(2026, 10, 5, 10),
      endAt: DateTime(2026, 10, 5, 11),
      isAvailable: true,
    ),
    AvailabilityBlock(
      id: 'tomorrow',
      startAt: DateTime(2026, 10, 6, 10),
      endAt: DateTime(2026, 10, 6, 12),
      isAvailable: true,
    ),
  ];
  TradeOffPlan option({int minutes = 60, bool agreement = false}) =>
      TradeOffPlan(
        id: 'option-1',
        title: 'Move reading',
        description: 'Rules-based move',
        taskId: 'reading',
        taskTitle: 'Reading',
        proposedStart: DateTime(2026, 10, 6, 10),
        proposedEnd: DateTime(2026, 10, 6, 10).add(Duration(minutes: minutes)),
        movedMinutes: minutes,
        needsAgreement: agreement,
      );
  TradeOffPreview preview({
    TaskItem? item,
    TradeOffPlan? plan,
    List<AvailabilityBlock>? blocks,
  }) => previewTradeOff(
    option: plan ?? option(),
    sourceDay: source,
    tasks: [item ?? task()],
    availability: blocks ?? availability,
    reservations: [],
    recoverySlots: [],
  );

  test('Preview simulates source and destination without mutating task', () {
    final original = task();
    final result = preview(item: original);
    expect(result.canApply, isTrue);
    final today = result.days.singleWhere((day) => day.day == source);
    final tomorrow = result.days.singleWhere((day) => day.day == destination);
    expect(today.before.plannedMinutes, 120);
    expect(today.after.plannedMinutes, 60);
    expect(today.before.overloadMinutes, 60);
    expect(today.after.overloadMinutes, 0);
    expect(tomorrow.after.plannedMinutes, 60);
    expect(original.effectiveRemainingMinutes, 120);
    expect(original.scheduledEnd, DateTime(2026, 10, 5, 12));
  });

  test('Protected and agreement-dependent work cannot apply', () {
    expect(preview(item: task(protected: true)).canApply, isFalse);
    expect(
      preview(item: task(flexibility: TaskFlexibility.fixed)).canApply,
      isFalse,
    );
    final agreement = preview(
      item: task(flexibility: TaskFlexibility.needsAgreement),
    );
    expect(agreement.canApply, isFalse);
    expect(agreement.issue, contains('Agreement'));
  });

  test('combined plan previews all task moves and affected capacity', () {
    final sourceTask = TaskItem(
      id: 'source-a',
      title: 'Assignment A',
      estimatedMinutes: 60,
      remainingMinutes: 60,
      dueAt: DateTime(2026, 10, 7),
      scheduledStart: DateTime(2026, 10, 5, 9),
      scheduledEnd: DateTime(2026, 10, 5, 10),
    );
    final secondTask = TaskItem(
      id: 'source-b',
      title: 'Assignment B',
      estimatedMinutes: 60,
      remainingMinutes: 60,
      dueAt: DateTime(2026, 10, 7),
      scheduledStart: DateTime(2026, 10, 5, 10),
      scheduledEnd: DateTime(2026, 10, 5, 11),
    );
    final blocks = [
      AvailabilityBlock(
        id: 'destination',
        startAt: DateTime(2026, 10, 6, 9),
        endAt: DateTime(2026, 10, 6, 11),
        isAvailable: true,
      ),
    ];
    final option = generateTradeOffs(
      day: source,
      tasks: [sourceTask, secondTask],
      availability: blocks,
      now: DateTime(2026, 10, 4),
    ).single;

    final result = previewTradeOff(
      option: option,
      sourceDay: source,
      tasks: [sourceTask, secondTask],
      availability: blocks,
      reservations: const [],
      recoverySlots: const [],
    );

    expect(result.canApply, isTrue);
    expect(result.option.allMoves, hasLength(2));
    expect(
      result.days.singleWhere((day) => day.day == source).after.overloadMinutes,
      0,
    );
    expect(
      result.days
          .singleWhere((day) => day.day == destination)
          .after
          .plannedMinutes,
      120,
    );

    final firstMove = option.allMoves.first;
    final secondMove = option.allMoves.last;
    final overlappingPlan = TradeOffPlan(
      id: 'invalid-overlap',
      title: 'Overlapping combined plan',
      description: 'Invalid test fixture',
      taskId: firstMove.taskId,
      taskTitle: '2 tasks',
      proposedStart: firstMove.proposedStart,
      proposedEnd: firstMove.proposedEnd,
      movedMinutes: 120,
      moves: [
        firstMove,
        TradeOffMove(
          taskId: secondMove.taskId,
          taskTitle: secondMove.taskTitle,
          proposedStart: firstMove.proposedStart,
          proposedEnd: firstMove.proposedEnd,
          movedMinutes: 60,
        ),
      ],
    );
    final rejected = previewTradeOff(
      option: overlappingPlan,
      sourceDay: source,
      tasks: [sourceTask, secondTask],
      availability: blocks,
      reservations: const [],
      recoverySlots: const [],
    );
    expect(rejected.canApply, isFalse);
    expect(rejected.issue, contains('proposed time'));
  });

  test(
    'Invalid duration or unresolved destination overload blocks preview',
    () {
      expect(preview(plan: option(minutes: 121)).canApply, isFalse);
      expect(preview(blocks: [availability.first]).canApply, isFalse);
      expect(
        preview(blocks: [availability.first]).issue,
        contains('proposed time'),
      );
    },
  );

  testWidgets(
    'Comparison explains capacity and picking an option is only a selection',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PlanComparisonSheet(previews: [preview()]),
                  );
                },
                child: const Text('Open comparison'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open comparison'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Planned: 120 → 60'), findsOneWidget);
      expect(find.textContaining('Nothing is saved here'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Select this option').hitTestable(),
        150,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select this option'));
      await tester.pumpAndSettle();
      expect(selected, 'option-1');
    },
  );

  testWidgets('Final review blocks agreement-dependent confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: PlanComparisonSheet(
              previews: [preview(plan: option(agreement: true))],
              confirmation: true,
            ),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Confirm this move'), 150);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm this move'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
