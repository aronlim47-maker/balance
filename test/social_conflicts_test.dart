import 'package:balance/domain/models/social_event_record.dart';
import 'package:balance/domain/models/task_item.dart';
import 'package:balance/domain/usecases/social_conflicts.dart';
import 'package:balance/domain/usecases/world_status_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clips an event to its week and merges overlapping commitments', () {
    final monday = DateTime(2026, 9, 28);
    final event = SocialEventRecord(
      id: 'social',
      startAt: monday.add(const Duration(hours: 10)),
      endAt: monday.add(const Duration(hours: 12)),
      pressure: SocialPressure.moderate,
    );
    final another = SocialEventRecord(
      id: 'other',
      startAt: monday.add(const Duration(hours: 10, minutes: 30)),
      endAt: monday.add(const Duration(hours: 11, minutes: 30)),
      pressure: SocialPressure.low,
    );
    final task = TaskItem(
      id: 'task',
      title: 'Study',
      estimatedMinutes: 60,
      dueAt: monday.add(const Duration(hours: 15)),
      scheduledStart: monday.add(const Duration(hours: 11)),
      scheduledEnd: monday.add(const Duration(hours: 12)),
    );
    final result = socialLoadForWeek(monday, [event, another], [task], [], []);
    expect(result.first.durationMinutes, 120);
    expect(result.first.conflictMinutes, 90);
    expect(result.first.sourceLabel, contains('Social event'));
  });

  test('does not count an event against its own linked task', () {
    final monday = DateTime(2026, 9, 28);
    final event = SocialEventRecord(
      id: 'social',
      taskId: 'task',
      startAt: monday.add(const Duration(hours: 10)),
      endAt: monday.add(const Duration(hours: 11)),
      pressure: SocialPressure.low,
    );
    final task = TaskItem(
      id: 'task',
      title: 'Meet',
      estimatedMinutes: 60,
      dueAt: monday.add(const Duration(hours: 12)),
      scheduledStart: event.startAt,
      scheduledEnd: event.endAt,
    );
    expect(
      socialLoadForWeek(monday, [event], [task], [], []).single.conflictMinutes,
      0,
    );
  });
}
