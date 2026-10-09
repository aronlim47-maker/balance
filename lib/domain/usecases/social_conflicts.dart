import '../enums/task_status.dart';
import '../models/plan_reservation.dart';
import '../models/recovery_slot.dart';
import '../models/social_event_record.dart';
import '../models/task_item.dart';
import 'world_status_calculator.dart';

/// Half-open intervals, clipped to the selected local week. Each minute of
/// conflict is counted once per event, even when several commitments overlap.
List<WorldSocialEvent> socialLoadForWeek(
  DateTime day,
  List<SocialEventRecord> events,
  List<TaskItem> tasks,
  List<PlanReservation> reservations,
  List<RecoverySlot> recovery,
) {
  final start = DateTime(day.year, day.month, day.day - day.weekday + 1);
  final end = DateTime(start.year, start.month, start.day + 7);
  final result = <WorldSocialEvent>[];
  for (final event in events) {
    final a = event.startAt.isBefore(start) ? start : event.startAt;
    final b = event.endAt.isAfter(end) ? end : event.endAt;
    if (b.difference(a).inMinutes <= 0) continue;
    final overlaps = <(DateTime, DateTime)>[];
    void add(DateTime from, DateTime to) {
      final left = from.isAfter(a) ? from : a;
      final right = to.isBefore(b) ? to : b;
      if (right.isAfter(left)) overlaps.add((left, right));
    }

    for (final other in events) {
      if (other.id != event.id) add(other.startAt, other.endAt);
    }
    for (final task in tasks) {
      if (task.id != event.taskId &&
          task.status == TaskStatus.planned &&
          task.scheduledStart != null &&
          task.scheduledEnd != null) {
        add(task.scheduledStart!, task.scheduledEnd!);
      }
    }
    for (final slot in reservations) {
      if (tasks.any(
        (task) => task.id == slot.taskId && task.status != TaskStatus.planned,
      )) {
        continue;
      }
      if (slot.taskId != event.taskId) add(slot.startAt, slot.endAt);
    }
    for (final slot in recovery) {
      if (slot.isProtected) add(slot.startAt, slot.endAt);
    }
    overlaps.sort((x, y) => x.$1.compareTo(y.$1));
    DateTime? left;
    DateTime? right;
    var seconds = 0;
    for (final interval in overlaps) {
      if (right == null || interval.$1.isAfter(right)) {
        if (right != null) seconds += right.difference(left!).inSeconds;
        left = interval.$1;
        right = interval.$2;
      } else if (interval.$2.isAfter(right)) {
        right = interval.$2;
      }
    }
    if (right != null) seconds += right.difference(left!).inSeconds;
    result.add(
      WorldSocialEvent(
        durationMinutes: b.difference(a).inMinutes,
        pressure: event.pressure,
        conflictMinutes: seconds ~/ 60,
        sourceLabel: _sourceLabel(event),
      ),
    );
  }
  return result;
}

String _sourceLabel(SocialEventRecord event) {
  final date = event.startAt.toLocal();
  return 'Social event · ${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
