import 'package:balance/domain/enums/task_flexibility.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/daily_capacity.dart';
import 'package:balance/domain/usecases/explain_no_feasible_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 9);

  NoPlanExplanation explain(
    List<TaskItem> tasks,
    List<AvailabilityBlock> availability,
  ) => explainNoFeasiblePlan(
    day: day,
    tasks: tasks,
    availability: availability,
    capacity: DailyCapacity.forDay(
      day: day,
      tasks: tasks,
      availability: availability,
    ),
  );

  AvailabilityBlock free(int fromHour, int toHour) => AvailabilityBlock(
    id: 'free-$fromHour',
    startAt: DateTime(2026, 10, 9, fromHour),
    endAt: DateTime(2026, 10, 9, toHour),
    isAvailable: true,
  );

  List<NoPlanReasonKind> kinds(NoPlanExplanation explanation) =>
      explanation.reasons.map((reason) => reason.kind).toList();

  test('230 protected + 50 unscheduled flexible: every cause is named', () {
    final explanation = explain(
      [
        TaskItem(
          id: 'thesis',
          title: 'Thesis',
          estimatedMinutes: 230,
          dueAt: DateTime(2026, 10, 9, 10),
          isProtected: true,
        ),
        TaskItem(
          id: 'lab',
          title: 'Lab report',
          estimatedMinutes: 50,
          dueAt: DateTime(2026, 10, 9, 22),
        ),
      ],
      [free(19, 23)],
    );

    expect(explanation.gapMinutes, 230);
    expect(explanation.extraWorkMinutes, 40);
    expect(explanation.dueBeforeFreeTimeMinutes, 190);
    expect(kinds(explanation), [
      NoPlanReasonKind.dueBeforeFreeTime,
      NoPlanReasonKind.flexibleUnscheduled,
      NoPlanReasonKind.protectedStays,
    ]);
    expect(explanation.reasons[0].message, contains('190 min'));
    expect(explanation.reasons[0].message, contains('7:00 PM'));
    expect(explanation.reasons[1].message, contains('"Lab report" (50 min)'));
    expect(explanation.reasons[1].message, contains('no time'));
    expect(explanation.reasons[1].taskId, 'lab');
    expect(explanation.reasons[2].message, contains('"Thesis" (230 min)'));
    expect(explanation.reasons[2].message, contains('protected'));
    expect(explanation.suggestsTasks, isTrue);
    expect(explanation.suggestsFreeTime, isTrue);
  });

  test('no availability says so first', () {
    final explanation = explain([
      TaskItem(
        id: 'essay',
        title: 'Essay',
        estimatedMinutes: 60,
        dueAt: DateTime(2026, 10, 9, 23),
      ),
    ], const []);

    expect(explanation.reasons.first.kind, NoPlanReasonKind.noFreeTime);
    expect(explanation.reasons.first.message, contains('Add your real'));
    expect(explanation.suggestsFreeTime, isTrue);
  });

  test('a scheduled flexible task with nowhere to go is named', () {
    final explanation = explain(
      [
        TaskItem(
          id: 'reading',
          title: 'Reading',
          estimatedMinutes: 180,
          dueAt: DateTime(2026, 10, 9, 23),
          scheduledStart: DateTime(2026, 10, 9, 19),
          scheduledEnd: DateTime(2026, 10, 9, 22),
        ),
        TaskItem(
          id: 'quiz',
          title: 'Quiz prep',
          estimatedMinutes: 60,
          dueAt: DateTime(2026, 10, 9, 23),
          flexibility: TaskFlexibility.fixed,
        ),
      ],
      [free(19, 22)],
    );

    expect(kinds(explanation), [
      NoPlanReasonKind.noLaterFreeTime,
      NoPlanReasonKind.protectedStays,
    ]);
    expect(explanation.reasons.first.message, contains('"Reading"'));
    expect(explanation.reasons.last.message, contains('fixed'));
  });

  test('needs-agreement work is explained, never treated as movable', () {
    final explanation = explain(
      [
        TaskItem(
          id: 'group',
          title: 'Group slides',
          estimatedMinutes: 120,
          dueAt: DateTime(2026, 10, 9, 23),
          flexibility: TaskFlexibility.needsAgreement,
        ),
      ],
      [free(21, 22)],
    );

    expect(kinds(explanation), contains(NoPlanReasonKind.needsAgreement));
    expect(
      kinds(explanation),
      isNot(contains(NoPlanReasonKind.flexibleUnscheduled)),
    );
  });

  test('tasks on other days are not blamed', () {
    final explanation = explain(
      [
        TaskItem(
          id: 'today',
          title: 'Today work',
          estimatedMinutes: 120,
          dueAt: DateTime(2026, 10, 9, 23),
          isProtected: true,
        ),
        TaskItem(
          id: 'later',
          title: 'Next week',
          estimatedMinutes: 60,
          dueAt: DateTime(2026, 10, 16, 12),
        ),
      ],
      [free(21, 22)],
    );

    expect(
      explanation.reasons.map((reason) => reason.taskId),
      isNot(contains('later')),
    );
  });

  test('protected rest in the only later free time is named', () {
    final tasks = [
      TaskItem(
        id: 'report',
        title: 'Report',
        estimatedMinutes: 180,
        dueAt: DateTime(2026, 10, 10, 17),
        scheduledStart: DateTime(2026, 10, 9, 9),
        scheduledEnd: DateTime(2026, 10, 9, 12),
      ),
      TaskItem(
        id: 'deadline',
        title: 'Deadline work',
        estimatedMinutes: 120,
        dueAt: DateTime(2026, 10, 9, 17),
      ),
    ];
    final availability = [
      free(9, 12),
      AvailabilityBlock(
        id: 'next',
        startAt: DateTime(2026, 10, 10, 9),
        endAt: DateTime(2026, 10, 10, 11),
        isAvailable: true,
      ),
    ];
    final explanation = explainNoFeasiblePlan(
      day: day,
      tasks: tasks,
      availability: availability,
      capacity: DailyCapacity.forDay(
        day: day,
        tasks: tasks,
        availability: availability,
      ),
      recoverySlots: [
        RecoverySlot(
          id: 'walk',
          startAt: DateTime(2026, 10, 10, 9),
          endAt: DateTime(2026, 10, 10, 9, 30),
        ),
      ],
    );
    final reason = explanation.reasons.firstWhere(
      (r) => r.kind == NoPlanReasonKind.noLaterFreeTime,
    );
    expect(reason.message, contains('protected recovery time (Sat 10 Oct, '));
    expect(reason.message, contains('Sanctuary'));
  });
}
