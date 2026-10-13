import 'package:balance/domain/enums/task_flexibility.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/suggest_free_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 9, 30);
  final now = DateTime(2026, 9, 26, 8);

  final report = TaskItem(
    id: 'report',
    title: 'Report',
    estimatedMinutes: 180,
    dueAt: DateTime(2026, 10, 3, 18),
    scheduledStart: DateTime(2026, 9, 30, 9),
    scheduledEnd: DateTime(2026, 9, 30, 12),
  );
  final sourceFree = AvailabilityBlock(
    id: 'source',
    startAt: DateTime(2026, 9, 30, 9),
    endAt: DateTime(2026, 9, 30, 10),
    isAvailable: true,
  );

  test('names the nearest later day and enough time to unlock a plan', () {
    final suggestion = suggestFreeTime(
      day: day,
      tasks: [report],
      availability: [sourceFree],
      now: now,
    );
    expect(suggestion, isNotNull);
    expect(suggestion!.day, DateTime(2026, 10, 1));
    expect(suggestion.minutes, 120);
    expect(suggestion.taskTitle, 'Report');
    expect(suggestion.start, DateTime(2026, 10, 1, 8));
    expect(suggestion.end, DateTime(2026, 10, 1, 10));
  });

  test('the suggested window avoids fixed work on that day', () {
    final suggestion = suggestFreeTime(
      day: day,
      tasks: [
        report,
        TaskItem(
          id: 'class',
          title: 'Class',
          estimatedMinutes: 60,
          dueAt: DateTime(2026, 10, 1, 9),
          flexibility: TaskFlexibility.fixed,
          scheduledStart: DateTime(2026, 10, 1, 8),
          scheduledEnd: DateTime(2026, 10, 1, 9),
        ),
      ],
      availability: [
        sourceFree,
        // The class has its own time, so 1 Oct is not over.
        AvailabilityBlock(
          id: 'class-time',
          startAt: DateTime(2026, 10, 1, 8),
          endAt: DateTime(2026, 10, 1, 9),
          isAvailable: true,
        ),
      ],
      now: now,
    );
    expect(suggestion!.day, DateTime(2026, 10, 1));
    expect(suggestion.start, DateTime(2026, 10, 1, 9));
  });

  test('no suggestion when the work is due on the day itself', () {
    expect(
      suggestFreeTime(
        day: day,
        tasks: [
          TaskItem(
            id: 'essay',
            title: 'Essay',
            estimatedMinutes: 120,
            dueAt: DateTime(2026, 9, 30, 18),
          ),
        ],
        availability: [sourceFree],
        now: DateTime(2026, 9, 30, 8),
      ),
      isNull,
    );
  });

  test('no suggestion for a balanced day, a past day or fixed work', () {
    expect(
      suggestFreeTime(
        day: day,
        tasks: [report],
        availability: [
          AvailabilityBlock(
            id: 'all',
            startAt: DateTime(2026, 9, 30, 9),
            endAt: DateTime(2026, 9, 30, 12),
            isAvailable: true,
          ),
        ],
        now: now,
      ),
      isNull,
    );
    expect(
      suggestFreeTime(
        day: day,
        tasks: [report],
        availability: [sourceFree],
        now: DateTime(2026, 10, 1, 8),
      ),
      isNull,
    );
    expect(
      suggestFreeTime(
        day: day,
        tasks: [
          TaskItem(
            id: 'shift',
            title: 'Shift',
            estimatedMinutes: 180,
            dueAt: DateTime(2026, 10, 3, 18),
            flexibility: TaskFlexibility.fixed,
            scheduledStart: DateTime(2026, 9, 30, 9),
            scheduledEnd: DateTime(2026, 9, 30, 12),
          ),
        ],
        availability: [sourceFree],
        now: now,
      ),
      isNull,
    );
  });

  test('prefers a day that needs less extra time; says when a day is over', () {
    final busyNextDay = TaskItem(
      id: 'shift',
      title: 'Shift',
      estimatedMinutes: 60,
      dueAt: DateTime(2026, 10, 1, 21),
      flexibility: TaskFlexibility.fixed,
      scheduledStart: DateTime(2026, 10, 1, 20),
      scheduledEnd: DateTime(2026, 10, 1, 21),
    );
    final suggestion = suggestFreeTime(
      day: day,
      tasks: [report, busyNextDay],
      availability: [sourceFree],
      now: now,
    );
    // 1 Oct is already 60 min over (180 needed); 29 Sep needs only 120.
    expect(suggestion!.day, DateTime(2026, 9, 29));
    expect(suggestion.minutes, 120);
    expect(suggestion.dayAlreadyOverMinutes, 0);

    // With 1 Oct the only day before the deadline, it is named with its
    // existing overload.
    final onlyNextDay = suggestFreeTime(
      day: day,
      tasks: [
        TaskItem(
          id: 'report',
          title: 'Report',
          estimatedMinutes: 180,
          dueAt: DateTime(2026, 10, 1, 23),
          scheduledStart: DateTime(2026, 9, 30, 9),
          scheduledEnd: DateTime(2026, 9, 30, 12),
        ),
        busyNextDay,
      ],
      availability: [sourceFree],
      now: DateTime(2026, 9, 30, 7),
    );
    expect(onlyNextDay!.day, DateTime(2026, 10, 1));
    expect(onlyNextDay.minutes, 180);
    expect(onlyNextDay.dayAlreadyOverMinutes, 60);
  });
}
