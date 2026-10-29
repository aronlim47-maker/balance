import 'dart:math' as math;

import '../enums/task_flexibility.dart';
import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/plan_reservation.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';
import 'daily_capacity.dart';
import 'generate_trade_offs.dart';

/// "Add [minutes] of free time on [day] and Council can move [taskTitle]
/// there." [start]–[end] is one free window that would work.
class FreeTimeSuggestion {
  const FreeTimeSuggestion({
    required this.day,
    required this.minutes,
    required this.taskTitle,
    required this.start,
    required this.end,
    this.dayAlreadyOverMinutes = 0,
  });

  final DateTime day;
  final int minutes;
  final String taskTitle;
  final DateTime start;
  final DateTime end;

  /// How far [day] is already over capacity; [minutes] covers this too.
  final int dayAlreadyOverMinutes;
}

/// When Council has no safe move for [day], finds the smallest amount of extra
/// free time on another day that would give it one. Each candidate is checked
/// by running Council on a copy of the data with that free time added, so a
/// suggestion is only shown when it really unlocks a plan. Nothing is saved.
FreeTimeSuggestion? suggestFreeTime({
  required DateTime day,
  required Iterable<TaskItem> tasks,
  required Iterable<AvailabilityBlock> availability,
  Iterable<PlanReservation> reservations = const [],
  Iterable<RecoverySlot> recoverySlots = const [],
  DateTime? now,
}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final today = _dateOnly(localNow);
  final selectedDay = _dateOnly(day.toLocal());
  if (selectedDay.isBefore(today)) return null;

  final allTasks = tasks.toList();
  final allAvailability = availability.toList();
  final allReservations = reservations.toList();
  final allRecovery = recoverySlots.toList();
  DailyCapacity capacityOn(DateTime target) => DailyCapacity.forDay(
    day: target,
    tasks: allTasks,
    availability: allAvailability,
    reservations: allReservations,
    recoverySlots: allRecovery,
  );
  final gap = capacityOn(selectedDay).overloadMinutes;
  if (gap == 0) return null;

  final candidates =
      allTasks.where((task) => _movableOn(task, selectedDay, localNow)).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  // Busy time a new free window must not cover: work, plans, protected rest,
  // blocked time, and free time already added (so nothing is counted twice).
  final busy = <_Interval>[
    for (final item in allTasks)
      if (item.status == TaskStatus.planned &&
          item.scheduledStart != null &&
          item.scheduledEnd != null)
        _Interval(item.scheduledStart!, item.scheduledEnd!),
    for (final item in allReservations) _Interval(item.startAt, item.endAt),
    for (final item in allRecovery)
      if (item.isProtected) _Interval(item.startAt, item.endAt),
    for (final block in allAvailability) _Interval(block.startAt, block.endAt),
  ]..sort((a, b) => a.start.compareTo(b.start));

  FreeTimeSuggestion? best;
  int distance(DateTime target) => target.difference(selectedDay).inDays.abs();
  bool better(FreeTimeSuggestion a, FreeTimeSuggestion b) {
    // Least extra free time first, then the nearest day, then the later day
    // (postponing reads more naturally than doing work early).
    if (a.minutes != b.minutes) return a.minutes < b.minutes;
    if (distance(a.day) != distance(b.day)) {
      return distance(a.day) < distance(b.day);
    }
    return a.day.isAfter(b.day);
  }

  for (final task in candidates.take(3)) {
    final due = task.dueAt.toLocal();
    for (
      var target = today;
      target.isBefore(due) && target.difference(today).inDays < 14;
      target = DateTime(target.year, target.month, target.day + 1)
    ) {
      if (DailyCapacity.sameDay(target, selectedDay)) continue;
      // Room for the whole gap plus anything the target day is already over.
      // Free time the target day still has spare counts too (D24), so try
      // the smaller amount first; Council checks each one below.
      final capacity = capacityOn(target);
      final alreadyOver = capacity.overloadMinutes;
      final spare = alreadyOver > 0
          ? 0
          : math.max(0, capacity.availableMinutes - capacity.plannedMinutes);
      final full = _roundUp(gap + alreadyOver, 15);
      final amounts = <int>{
        if (spare > 0) _roundUp(math.max(15, gap - spare), 15),
        full,
      };
      for (final needed in amounts) {
        if (best != null && needed > best.minutes) continue;
        final window = _freeWindow(
          day: target,
          minutes: needed,
          notBefore: localNow,
          notAfter: task.dueAt,
          busy: busy,
        );
        if (window == null) continue;
        final options = generateTradeOffs(
          day: selectedDay,
          tasks: allTasks,
          availability: [
            ...allAvailability,
            AvailabilityBlock(
              id: 'suggested',
              startAt: window.start,
              endAt: window.end,
              isAvailable: true,
            ),
          ],
          reservations: allReservations,
          recoverySlots: allRecovery,
          now: localNow,
        );
        if (options.isEmpty) continue;
        final suggestion = FreeTimeSuggestion(
          day: target,
          minutes: needed,
          taskTitle: task.title,
          start: window.start,
          end: window.end,
          dayAlreadyOverMinutes: alreadyOver,
        );
        if (best == null || better(suggestion, best)) best = suggestion;
        break;
      }
    }
  }
  return best;
}

bool _movableOn(TaskItem task, DateTime day, DateTime localNow) {
  if (task.status != TaskStatus.planned ||
      task.isProtected ||
      task.flexibility != TaskFlexibility.flexible ||
      task.effectiveRemainingMinutes <= 0 ||
      !task.dueAt.isAfter(localNow)) {
    return false;
  }
  final start = task.scheduledStart;
  final end = task.scheduledEnd;
  if (start == null || end == null) {
    return DailyCapacity.sameDay(task.dueAt.toLocal(), day);
  }
  return DailyCapacity.overlapsDay(start, end, day);
}

/// The first [minutes]-long gap on [day] between 8 AM and 11 PM (and after
/// [notBefore], ending by [notAfter]) that overlaps nothing in [busy].
_Interval? _freeWindow({
  required DateTime day,
  required int minutes,
  required DateTime notBefore,
  required DateTime notAfter,
  required List<_Interval> busy,
}) {
  final duration = Duration(minutes: minutes);
  final dayStart = DateTime(day.year, day.month, day.day, 8);
  final dayEnd = DateTime(day.year, day.month, day.day, 23);
  var candidate = dayStart.isAfter(notBefore)
      ? dayStart
      : _roundUpToQuarter(notBefore);
  final limit = dayEnd.isBefore(notAfter.toLocal())
      ? dayEnd
      : notAfter.toLocal();
  for (final interval in busy) {
    final start = interval.start.toLocal();
    final end = interval.end.toLocal();
    if (!end.isAfter(candidate) || !start.isBefore(limit)) continue;
    if (!start.isBefore(candidate.add(duration))) break;
    candidate = _roundUpToQuarter(end);
  }
  final finish = candidate.add(duration);
  return finish.isAfter(limit) ? null : _Interval(candidate, finish);
}

DateTime _roundUpToQuarter(DateTime time) {
  final local = time.toLocal();
  final base = DateTime(local.year, local.month, local.day, local.hour);
  final minutes =
      local.minute + (local.second > 0 || local.millisecond > 0 ? 1 : 0);
  return base.add(Duration(minutes: _roundUp(minutes, 15)));
}

int _roundUp(int value, int step) => ((value + step - 1) ~/ step) * step;

DateTime _dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

class _Interval {
  const _Interval(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
