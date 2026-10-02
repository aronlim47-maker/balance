import '../enums/task_flexibility.dart';
import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/plan_reservation.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';
import 'daily_capacity.dart';

/// A single task move that can be confirmed without another person's consent.
class TradeOffPlan {
  const TradeOffPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.taskId,
    required this.taskTitle,
    required this.proposedStart,
    required this.proposedEnd,
    required this.movedMinutes,
    this.needsAgreement = false,
  });

  final String id;
  final String title;
  final String description;
  final String taskId;
  final String taskTitle;
  final DateTime proposedStart;
  final DateTime proposedEnd;
  final int movedMinutes;
  final bool needsAgreement;
}

/// Generates at most three feasible, single-task moves from one overloaded day.
/// The live database still revalidates a choice when it is confirmed.
List<TradeOffPlan> generateTradeOffs({
  required DateTime day,
  required Iterable<TaskItem> tasks,
  required Iterable<AvailabilityBlock> availability,
  Iterable<PlanReservation> reservations = const [],
  Iterable<RecoverySlot> recoverySlots = const [],
  bool includeNeedsAgreement = false,
  DateTime? now,
}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final selectedDay = _dateOnly(day.toLocal());
  if (selectedDay.isBefore(_dateOnly(localNow))) return const [];

  final allTasks = tasks.toList();
  final allAvailability = availability.toList();
  final allReservations = reservations.toList();
  final allRecovery = recoverySlots.toList();
  final sourceCapacity = DailyCapacity.forDay(
    day: selectedDay,
    tasks: allTasks,
    availability: allAvailability,
    reservations: allReservations,
    recoverySlots: allRecovery,
  );
  if (sourceCapacity.overloadMinutes == 0) return const [];

  final movableTasks =
      allTasks.where((task) {
        final start = task.scheduledStart;
        final end = task.scheduledEnd;
        final remaining = task.effectiveRemainingMinutes;
        return task.status == TaskStatus.planned &&
            (task.flexibility == TaskFlexibility.flexible ||
                (includeNeedsAgreement &&
                    task.flexibility == TaskFlexibility.needsAgreement)) &&
            !task.isProtected &&
            start != null &&
            end != null &&
            remaining > 0 &&
            end.difference(start).inMicroseconds ==
                Duration(minutes: remaining).inMicroseconds &&
            !end.isAfter(task.dueAt) &&
            task.dueAt.isAfter(localNow) &&
            DailyCapacity.overlapsDay(start, end, selectedDay);
      }).toList()..sort((a, b) {
        final byStart = a.scheduledStart!.compareTo(b.scheduledStart!);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });

  final results = <TradeOffPlan>[];
  for (final task in movableTasks) {
    final movedMinutes = _minimumMoveThatClearsSource(
      task: task,
      day: selectedDay,
      tasks: allTasks,
      availability: allAvailability,
      reservations: allReservations,
      recoverySlots: allRecovery,
    );
    if (movedMinutes == null) continue;

    final remainingTask = _withRemainingMinutes(
      task,
      task.effectiveRemainingMinutes - movedMinutes,
    );
    final revisedTasks = [
      for (final item in allTasks) item.id == task.id ? remainingTask : item,
    ];
    final duration = Duration(minutes: movedMinutes);
    final busy = <_Interval>[
      for (final item in revisedTasks)
        if (item.status == TaskStatus.planned &&
            item.scheduledStart != null &&
            item.scheduledEnd != null)
          _Interval(item.scheduledStart!, item.scheduledEnd!),
      for (final item in allReservations) _Interval(item.startAt, item.endAt),
      for (final item in allRecovery)
        if (item.isProtected) _Interval(item.startAt, item.endAt),
      for (final block in allAvailability)
        if (!block.isAvailable) _Interval(block.startAt, block.endAt),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final availableBlocks =
        allAvailability
            .where(
              (block) =>
                  block.isAvailable && block.endAt.isAfter(block.startAt),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    TradeOffPlan? option;
    for (final block in availableBlocks) {
      var cursor = _later(block.startAt, localNow);
      final blockEnd = _earlier(block.endAt, task.dueAt);
      while (cursor.isBefore(blockEnd)) {
        final targetDay = _dateOnly(cursor.toLocal());
        final nextDay = DateTime(
          targetDay.year,
          targetDay.month,
          targetDay.day + 1,
        );
        final segmentEnd = _earlier(blockEnd, nextDay);
        if (!DailyCapacity.sameDay(targetDay, selectedDay)) {
          final start = _firstFreeStart(
            from: cursor,
            until: segmentEnd,
            duration: duration,
            busy: busy,
          );
          if (start != null) {
            final end = start.add(duration);
            final proposedReservations = [
              ...allReservations,
              PlanReservation(taskId: task.id, startAt: start, endAt: end),
            ];
            if (_affectedDaysAreClear(
              originalTask: task,
              destinationDay: targetDay,
              tasks: revisedTasks,
              availability: allAvailability,
              reservations: proposedReservations,
              recoverySlots: allRecovery,
            )) {
              final date = _dateLabel(targetDay);
              option = TradeOffPlan(
                id: '${task.id}:${start.toUtc().toIso8601String()}:$movedMinutes',
                title: 'Move ${task.title} to $date',
                description:
                    'Move $movedMinutes minutes to $date, '
                    '${_timeLabel(start)}–${_timeLabel(end)} before the deadline.',
                taskId: task.id,
                taskTitle: task.title,
                proposedStart: start,
                proposedEnd: end,
                movedMinutes: movedMinutes,
                needsAgreement:
                    task.flexibility == TaskFlexibility.needsAgreement,
              );
              break;
            }
          }
        }
        cursor = nextDay;
      }
      if (option != null) break;
    }
    if (option != null) results.add(option);
    if (results.length == 3) break;
  }
  return results;
}

int? _minimumMoveThatClearsSource({
  required TaskItem task,
  required DateTime day,
  required List<TaskItem> tasks,
  required List<AvailabilityBlock> availability,
  required List<PlanReservation> reservations,
  required List<RecoverySlot> recoverySlots,
}) {
  bool clearsWith(int moved) {
    final updated = _withRemainingMinutes(
      task,
      task.effectiveRemainingMinutes - moved,
    );
    return DailyCapacity.forDay(
          day: day,
          tasks: [
            for (final item in tasks) item.id == task.id ? updated : item,
          ],
          availability: availability,
          reservations: reservations,
          recoverySlots: recoverySlots,
        ).overloadMinutes ==
        0;
  }

  if (!clearsWith(task.effectiveRemainingMinutes)) return null;
  var low = 1;
  var high = task.effectiveRemainingMinutes;
  while (low < high) {
    final middle = low + ((high - low) ~/ 2);
    if (clearsWith(middle)) {
      high = middle;
    } else {
      low = middle + 1;
    }
  }
  return low;
}

TaskItem _withRemainingMinutes(TaskItem task, int remaining) {
  final start = remaining == 0 ? null : task.scheduledStart;
  return TaskItem(
    id: task.id,
    title: task.title,
    estimatedMinutes: task.estimatedMinutes,
    dueAt: task.dueAt,
    flexibility: task.flexibility,
    status: task.status,
    isProtected: task.isProtected,
    protectedCommitmentType: task.protectedCommitmentType,
    isOptional: task.isOptional,
    loadCategory: task.loadCategory,
    remainingMinutes: remaining,
    scheduledStart: start,
    scheduledEnd: start?.add(Duration(minutes: remaining)),
  );
}

bool _affectedDaysAreClear({
  required TaskItem originalTask,
  required DateTime destinationDay,
  required List<TaskItem> tasks,
  required List<AvailabilityBlock> availability,
  required List<PlanReservation> reservations,
  required List<RecoverySlot> recoverySlots,
}) {
  final start = _dateOnly(originalTask.scheduledStart!.toLocal());
  final end = originalTask.scheduledEnd!.toLocal();
  for (
    var day = start;
    day.isBefore(end);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (DailyCapacity.forDay(
          day: day,
          tasks: tasks,
          availability: availability,
          reservations: reservations,
          recoverySlots: recoverySlots,
        ).overloadMinutes >
        0) {
      return false;
    }
  }
  return DailyCapacity.forDay(
        day: destinationDay,
        tasks: tasks,
        availability: availability,
        reservations: reservations,
        recoverySlots: recoverySlots,
      ).overloadMinutes ==
      0;
}

DateTime? _firstFreeStart({
  required DateTime from,
  required DateTime until,
  required Duration duration,
  required List<_Interval> busy,
}) {
  var candidate = from;
  for (final interval in busy) {
    if (!interval.end.isAfter(candidate) || !interval.start.isBefore(until)) {
      continue;
    }
    if (!interval.start.isBefore(candidate.add(duration))) return candidate;
    candidate = _later(candidate, interval.end);
    if (candidate.add(duration).isAfter(until)) return null;
  }
  return candidate.add(duration).isAfter(until) ? null : candidate;
}

DateTime _dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);
DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
String _dateLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _timeLabel(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class _Interval {
  const _Interval(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
