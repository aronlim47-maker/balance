import 'package:balance/domain/enums/task_flexibility.dart';
import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/plan_reservation.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/generate_trade_offs.dart';
import 'package:balance/domain/usecases/daily_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 9, 30);
  final now = DateTime(2026, 9, 26, 8);

  test('moves exactly enough work to clear the source gap', () {
    final task = _task(start: DateTime(2026, 9, 30, 9), minutes: 300);
    final options = generateTradeOffs(
      day: day,
      tasks: [task],
      availability: [
        _available(DateTime(2026, 9, 30, 9), 180),
        _available(DateTime(2026, 10, 1, 9), 180),
      ],
      now: now,
    );
    expect(options, hasLength(1));
    expect(options.single.taskId, task.id);
    expect(options.single.movedMinutes, 120);
    expect(options.single.proposedStart, DateTime(2026, 10, 1, 9));
    expect(options.single.proposedEnd, DateTime(2026, 10, 1, 11));
    expect(options.single.needsAgreement, isFalse);
  });

  test('moves scheduled work to make room for work due today', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [
        _task(start: DateTime(2026, 9, 30, 9), minutes: 180),
        _task(
          id: 'due-today',
          start: DateTime(2026, 9, 30, 9),
          minutes: 120,
          due: DateTime(2026, 9, 30, 18),
          scheduled: false,
        ),
      ],
      availability: [
        _available(DateTime(2026, 9, 30, 9), 180),
        _available(DateTime(2026, 10, 1, 9), 120),
      ],
      now: now,
    );
    expect(options, hasLength(1));
    expect(options.single.taskId, 'source');
    expect(options.single.movedMinutes, 120);
    expect(options.single.proposedStart, DateTime(2026, 10, 1, 9));
  });

  test('capacity checks work due before later availability', () {
    final snapshot = DailyCapacity.forDay(
      day: day,
      tasks: [
        _task(
          id: 'noon-deadline',
          start: DateTime(2026, 9, 30, 9),
          minutes: 60,
          due: DateTime(2026, 9, 30, 12),
          scheduled: false,
        ),
      ],
      availability: [_available(DateTime(2026, 9, 30, 13), 120)],
    );
    expect(snapshot.plannedMinutes, 60);
    expect(snapshot.availableMinutes, 120);
    expect(snapshot.overloadMinutes, 60);
  });

  test('never moves fixed, protected, agreement or unplanned work', () {
    final source = DateTime(2026, 9, 30, 9);
    final cases = [
      _task(start: source, flexibility: TaskFlexibility.fixed),
      _task(start: source, flexibility: TaskFlexibility.needsAgreement),
      _task(start: source, protected: true),
      _task(start: source, status: TaskStatus.completed),
      _task(start: source, scheduled: false),
    ];
    for (final task in cases) {
      expect(
        generateTradeOffs(
          day: day,
          tasks: [task],
          availability: [
            _available(source, 60),
            _available(DateTime(2026, 10, 1, 9), 120),
          ],
          now: now,
        ),
        isEmpty,
      );
    }
  });

  test('shows agreement-dependent ideas without marking them confirmable', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [
        _task(
          start: DateTime(2026, 9, 30, 9),
          minutes: 180,
          flexibility: TaskFlexibility.needsAgreement,
        ),
        _task(
          id: 'due-today',
          start: DateTime(2026, 9, 30, 9),
          minutes: 120,
          due: DateTime(2026, 9, 30, 18),
          scheduled: false,
        ),
      ],
      availability: [
        _available(DateTime(2026, 9, 30, 9), 180),
        _available(DateTime(2026, 10, 1, 9), 120),
      ],
      includeNeedsAgreement: true,
      now: now,
    );
    expect(options, hasLength(1));
    expect(options.single.needsAgreement, isTrue);
    expect(options.single.movedMinutes, 120);
  });

  test('avoids other tasks, confirmed moves and protected recovery', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [
        _task(start: DateTime(2026, 9, 30, 9)),
        _task(id: 'other', start: DateTime(2026, 10, 1, 9), minutes: 60),
      ],
      availability: [
        _available(DateTime(2026, 9, 30, 9), 60),
        _available(DateTime(2026, 10, 1, 9), 240),
      ],
      reservations: [
        PlanReservation(
          taskId: 'confirmed',
          startAt: DateTime(2026, 10, 1, 10),
          endAt: DateTime(2026, 10, 1, 11),
        ),
      ],
      recoverySlots: [
        RecoverySlot(
          id: 'rest',
          startAt: DateTime(2026, 10, 1, 11),
          endAt: DateTime(2026, 10, 1, 12),
        ),
      ],
      now: now,
    );
    expect(options, hasLength(1));
    expect(options.single.proposedStart, DateTime(2026, 10, 1, 12));
    expect(options.single.proposedEnd, DateTime(2026, 10, 1, 13));
  });

  test('rejects a free slot if the destination day would be overloaded', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [
        _task(start: DateTime(2026, 9, 30, 9)),
        _task(
          id: 'backlog',
          start: DateTime(2026, 10, 1, 9),
          minutes: 200,
          due: DateTime(2026, 10, 1, 18),
          scheduled: false,
        ),
      ],
      availability: [
        _available(DateTime(2026, 9, 30, 9), 60),
        _available(DateTime(2026, 10, 1, 9), 240),
      ],
      now: now,
    );
    expect(options, isEmpty);
  });

  test('moves enough of a cross-midnight tail to fix the chosen day', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [_task(start: DateTime(2026, 9, 30, 23), minutes: 180)],
      availability: [
        _available(DateTime(2026, 9, 30, 23), 30),
        _available(DateTime(2026, 10, 2, 9), 180),
      ],
      now: now,
    );
    expect(options, hasLength(1));
    expect(options.single.movedMinutes, 150);
    expect(options.single.proposedStart, DateTime(2026, 10, 2, 9));
  });

  test('never schedules in the past or after the deadline', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [
        _task(
          start: DateTime(2026, 9, 30, 19),
          due: DateTime(2026, 10, 1, 9, 30),
        ),
      ],
      availability: [
        _available(DateTime(2026, 9, 30, 19), 60),
        _available(DateTime(2026, 9, 29, 9), 120),
        _available(DateTime(2026, 10, 1, 9), 120),
      ],
      now: DateTime(2026, 9, 30, 18),
    );
    expect(options, isEmpty);
  });

  test('returns no more than three separate task options', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [
        for (var index = 0; index < 4; index++)
          _task(
            id: 'task-$index',
            start: DateTime(2026, 9, 30, 9 + index),
            minutes: 60,
          ),
      ],
      availability: [
        _available(DateTime(2026, 9, 30, 9), 180),
        _available(DateTime(2026, 10, 1, 9), 240),
      ],
      now: now,
    );
    expect(options, hasLength(3));
    expect(options.map((item) => item.taskId).toSet(), hasLength(3));
  });

  test('combines multiple task moves when no single move clears the gap', () {
    final options = generateTradeOffs(
      day: day,
      tasks: [
        _task(id: 'first', start: DateTime(2026, 9, 30, 9), minutes: 60),
        _task(id: 'second', start: DateTime(2026, 9, 30, 10), minutes: 60),
      ],
      availability: [_available(DateTime(2026, 10, 1, 9), 120)],
      now: now,
    );

    expect(options, hasLength(1));
    final plan = options.single;
    expect(plan.allMoves, hasLength(2));
    expect(plan.allMoves.map((move) => move.taskId), ['first', 'second']);
    expect(plan.allMoves.map((move) => move.movedMinutes), [60, 60]);
    expect(plan.movedMinutes, 120);
    expect(plan.title, contains('2 tasks'));
  });

  test('does not combine protected work or exceed destination capacity', () {
    final first = _task(
      id: 'first',
      start: DateTime(2026, 9, 30, 9),
      minutes: 60,
    );
    expect(
      generateTradeOffs(
        day: day,
        tasks: [
          first,
          _task(
            id: 'protected',
            start: DateTime(2026, 9, 30, 10),
            minutes: 60,
            protected: true,
          ),
        ],
        availability: [_available(DateTime(2026, 10, 1, 9), 120)],
        now: now,
      ),
      isEmpty,
    );
    expect(
      generateTradeOffs(
        day: day,
        tasks: [
          first,
          _task(id: 'second', start: DateTime(2026, 9, 30, 10), minutes: 60),
        ],
        availability: [_available(DateTime(2026, 10, 1, 9), 60)],
        now: now,
      ),
      isEmpty,
    );
  });
}

TaskItem _task({
  String id = 'source',
  required DateTime start,
  int minutes = 120,
  DateTime? due,
  TaskFlexibility flexibility = TaskFlexibility.flexible,
  TaskStatus status = TaskStatus.planned,
  bool protected = false,
  bool scheduled = true,
}) => TaskItem(
  id: id,
  title: 'Task $id',
  estimatedMinutes: minutes,
  remainingMinutes: minutes,
  dueAt: due ?? DateTime(2026, 10, 3, 18),
  flexibility: flexibility,
  status: status,
  isProtected: protected,
  scheduledStart: scheduled ? start : null,
  scheduledEnd: scheduled ? start.add(Duration(minutes: minutes)) : null,
);

AvailabilityBlock _available(DateTime start, int minutes) => AvailabilityBlock(
  id: 'available-${start.toIso8601String()}',
  startAt: start,
  endAt: start.add(Duration(minutes: minutes)),
  isAvailable: true,
);
