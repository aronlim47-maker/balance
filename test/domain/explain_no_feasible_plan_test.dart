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
    now: DateTime(2026, 10, 9, 8),
  );

  AvailabilityBlock free(int fromHour, int toHour) => AvailabilityBlock(
    id: 'free-$fromHour',
    startAt: DateTime(2026, 10, 9, fromHour),
    endAt: DateTime(2026, 10, 9, toHour),
    isAvailable: true,
  );

  List<NoPlanReasonKind> kinds(NoPlanExplanation explanation) =>
      explanation.reasons.map((reason) => reason.kind).toList();

  test('230 protected + 50 flexible due today: every cause is named', () {
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
      NoPlanReasonKind.noOtherDay,
      NoPlanReasonKind.protectedStays,
    ]);
    expect(explanation.reasons[0].message, contains('190 min'));
    expect(explanation.reasons[0].message, contains('7:00 PM'));
    // True also when the deadline is after the free time starts (D26).
    expect(
      explanation.reasons[0].message,
      contains('due before there is enough free time for it'),
    );
    expect(explanation.reasons[1].message, contains('"Lab report" (50 min)'));
    expect(explanation.reasons[1].message, contains('no other day'));
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
          dueAt: DateTime(2026, 10, 10, 23),
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
    // Other days may have some free time, just not enough (D23).
    expect(
      explanation.reasons.first.message,
      startsWith('Not enough free time was found'),
    );
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
    expect(kinds(explanation), isNot(contains(NoPlanReasonKind.noOtherDay)));
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

  test('a past day says it has passed instead of listing reasons', () {
    final tasks = [
      TaskItem(
        id: 'essay',
        title: 'Essay',
        estimatedMinutes: 300,
        dueAt: DateTime(2026, 10, 9, 23),
      ),
    ];
    final availability = [free(9, 12)];
    NoPlanExplanation at(DateTime now) => explainNoFeasiblePlan(
      day: day,
      tasks: tasks,
      availability: availability,
      capacity: DailyCapacity.forDay(
        day: day,
        tasks: tasks,
        availability: availability,
      ),
      now: now,
    );

    final past = at(DateTime(2026, 10, 10, 9));
    expect(kinds(past), [NoPlanReasonKind.dayPassed]);
    expect(past.reasons.single.message, contains('already passed'));
    expect(past.suggestsTasks, isFalse);
    expect(past.suggestsFreeTime, isFalse);

    // Later the same day it is still today, so the usual reasons show.
    final sameDay = at(DateTime(2026, 10, 9, 20));
    expect(kinds(sameDay), isNot(contains(NoPlanReasonKind.dayPassed)));
    expect(sameDay.reasons, isNotEmpty);
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
        // As loaded from the server: UTC, shown in local time.
        RecoverySlot(
          id: 'walk',
          startAt: DateTime(2026, 10, 10, 9).toUtc(),
          endAt: DateTime(2026, 10, 10, 9, 30).toUtc(),
        ),
      ],
      now: DateTime(2026, 10, 9, 8),
    );
    final reason = explanation.reasons.firstWhere(
      (r) => r.kind == NoPlanReasonKind.noLaterFreeTime,
    );
    expect(
      reason.message,
      contains('protected recovery time (Sat 10 Oct, 9:00 AM)'),
    );
    expect(reason.message, contains('Sanctuary'));
  });

  test('unscheduled flexible work due later is movable, not blamed for '
      'missing a start time', () {
    final explanation = explain(
      [
        TaskItem(
          id: 'essay',
          title: 'Essay',
          estimatedMinutes: 120,
          dueAt: DateTime(2026, 10, 9, 23),
        ),
      ],
      [free(21, 22)],
    );
    // Due today with no earlier day left: there is no other day.
    expect(kinds(explanation), contains(NoPlanReasonKind.noOtherDay));

    final viewedEarly = explainNoFeasiblePlan(
      day: day,
      tasks: [
        TaskItem(
          id: 'essay',
          title: 'Essay',
          estimatedMinutes: 120,
          dueAt: DateTime(2026, 10, 9, 23),
        ),
      ],
      availability: [free(21, 22)],
      capacity: DailyCapacity.forDay(
        day: day,
        tasks: [
          TaskItem(
            id: 'essay',
            title: 'Essay',
            estimatedMinutes: 120,
            dueAt: DateTime(2026, 10, 9, 23),
          ),
        ],
        availability: [free(21, 22)],
      ),
      now: DateTime(2026, 10, 7, 8),
    );
    // Viewed two days earlier, earlier days could take it: ask for free time.
    expect(kinds(viewedEarly), contains(NoPlanReasonKind.noLaterFreeTime));
    expect(kinds(viewedEarly), isNot(contains(NoPlanReasonKind.noOtherDay)));
  });
}
