import 'package:balance/domain/enums/task_status.dart';
import 'package:balance/domain/models/availability_block.dart';
import 'package:balance/domain/models/recovery_slot.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/free_windows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 10);
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 10, h, m);
  AvailabilityBlock block(int from, int to, {bool available = true}) =>
      AvailabilityBlock(
        id: 'b$from',
        startAt: at(from),
        endAt: at(to),
        isAvailable: available,
      );
  TaskItem task(DateTime start, DateTime end, {TaskStatus? status}) => TaskItem(
    id: 't${start.hour}',
    title: 'Work',
    estimatedMinutes: end.difference(start).inMinutes,
    dueAt: at(23),
    scheduledStart: start,
    scheduledEnd: end,
    status: status ?? TaskStatus.planned,
  );
  String fmt(List<FreeWindow> ws) => ws
      .map(
        (w) =>
            '${w.start.hour}:${w.start.minute}-${w.end.hour}:${w.end.minute}',
      )
      .join(', ');

  test('no availability means no free time', () {
    expect(
      freeWindowsOn(
        day,
        availability: const [],
        tasks: const [],
        recovery: const [],
      ),
      isEmpty,
    );
  });

  test('scheduled work and existing recovery are taken out', () {
    final windows = freeWindowsOn(
      day,
      availability: [block(9, 12)],
      tasks: [task(at(9), at(10))],
      recovery: [RecoverySlot(id: 'r', startAt: at(11), endAt: at(11, 30))],
    );
    expect(fmt(windows), '10:0-11:0, 11:30-12:0');
  });

  test('blocked time, done tasks and short gaps', () {
    final windows = freeWindowsOn(
      day,
      availability: [block(9, 12), block(10, 11, available: false)],
      tasks: [
        task(at(9), at(9, 50)),
        task(at(11), at(12), status: TaskStatus.completed),
      ],
      recovery: const [],
    );
    // 9:50-10:00 is under 15 minutes; the completed task frees 11-12.
    expect(fmt(windows), '11:0-12:0');
  });

  test('time already passed today is not offered', () {
    final windows = freeWindowsOn(
      day,
      availability: [block(9, 12)],
      tasks: const [],
      recovery: const [],
      now: at(10, 15),
    );
    expect(fmt(windows), '10:15-12:0');
  });

  test('the slot being edited does not block itself', () {
    final slot = RecoverySlot(id: 'r', startAt: at(9), endAt: at(10));
    final windows = freeWindowsOn(
      day,
      availability: [block(9, 10)],
      tasks: const [],
      recovery: [slot],
      exceptSlotId: 'r',
    );
    expect(fmt(windows), '9:0-10:0');
  });
}
