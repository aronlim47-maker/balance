import '../enums/task_flexibility.dart';
import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/plan_reservation.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';
import 'daily_capacity.dart';

/// A single task move that can be confirmed without another person's consent.
class TradeOffMove {
  const TradeOffMove({
    required this.taskId,
    required this.taskTitle,
    required this.proposedStart,
    required this.proposedEnd,
    required this.movedMinutes,
    this.needsAgreement = false,
  });

  final String taskId;
  final String taskTitle;
  final DateTime proposedStart;
  final DateTime proposedEnd;
  final int movedMinutes;
  final bool needsAgreement;
}

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
    this.moves = const [],
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
  final List<TradeOffMove> moves;

  /// Legacy single-move plans are normalized to the same list contract used
  /// for a plan containing several task moves.
  List<TradeOffMove> get allMoves => moves.isNotEmpty
      ? moves
      : [
          TradeOffMove(
            taskId: taskId,
            taskTitle: taskTitle,
            proposedStart: proposedStart,
            proposedEnd: proposedEnd,
            movedMinutes: movedMinutes,
            needsAgreement: needsAgreement,
          ),
        ];
}

/// Generates feasible alternatives from one overloaded day. If no one-task
/// move can clear the day, it tries a bounded, explainable combination of moves.
/// The live database still revalidates every choice when it is confirmed.
List<TradeOffPlan> generateTradeOffs({
  required DateTime day,
  required Iterable<TaskItem> tasks,
  required Iterable<AvailabilityBlock> availability,
  Iterable<PlanReservation> reservations = const [],
  Iterable<RecoverySlot> recoverySlots = const [],
  bool includeNeedsAgreement = false,
  DateTime? now,
}) {
  final singles = _generateSingleTradeOffs(
    day: day,
    tasks: tasks,
    availability: availability,
    reservations: reservations,
    recoverySlots: recoverySlots,
    includeNeedsAgreement: includeNeedsAgreement,
    now: now,
  );
  if (singles.isNotEmpty) return singles;
  final combined = _generateCombinedTradeOff(
    day: day,
    tasks: tasks,
    availability: availability,
    reservations: reservations,
    recoverySlots: recoverySlots,
    includeNeedsAgreement: includeNeedsAgreement,
    now: now,
  );
  return combined == null ? const [] : [combined];
}

List<TradeOffPlan> _generateSingleTradeOffs({
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

TradeOffPlan? _generateCombinedTradeOff({
  required DateTime day,
  required Iterable<TaskItem> tasks,
  required Iterable<AvailabilityBlock> availability,
  required Iterable<PlanReservation> reservations,
  required Iterable<RecoverySlot> recoverySlots,
  required bool includeNeedsAgreement,
  required DateTime? now,
}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final selectedDay = _dateOnly(day.toLocal());
  if (selectedDay.isBefore(_dateOnly(localNow))) return null;

  final allTasks = tasks.toList();
  final allAvailability = availability.toList();
  final allReservations = reservations.toList();
  final allRecovery = recoverySlots.toList();
  final initialGap = DailyCapacity.forDay(
    day: selectedDay,
    tasks: allTasks,
    availability: allAvailability,
    reservations: allReservations,
    recoverySlots: allRecovery,
  ).overloadMinutes;
  if (initialGap <= 0) return null;

  // Restrict the first combined planner to tasks fully contained in the source
  // day. This makes each moved minute's source-day effect exact and avoids
  // over-promising for cross-midnight work, which the single-task path handles.
  final candidates =
      allTasks.where((task) {
        final start = task.scheduledStart;
        final end = task.scheduledEnd;
        return task.status == TaskStatus.planned &&
            (task.flexibility == TaskFlexibility.flexible ||
                (includeNeedsAgreement &&
                    task.flexibility == TaskFlexibility.needsAgreement)) &&
            !task.isProtected &&
            start != null &&
            end != null &&
            task.effectiveRemainingMinutes > 0 &&
            end.difference(start).inMicroseconds ==
                Duration(minutes: task.effectiveRemainingMinutes)
                    .inMicroseconds &&
            DailyCapacity.sameDay(start.toLocal(), selectedDay) &&
            DailyCapacity.sameDay(
              end.subtract(const Duration(microseconds: 1)).toLocal(),
              selectedDay,
            ) &&
            !end.isAfter(task.dueAt) &&
            task.dueAt.isAfter(localNow);
      }).toList()..sort((a, b) {
        final byDeadline = a.dueAt.compareTo(b.dueAt);
        if (byDeadline != 0) return byDeadline;
        final byStart = a.scheduledStart!.compareTo(b.scheduledStart!);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });

  var revisedTasks = List<TaskItem>.of(allTasks);
  var proposedReservations = List<PlanReservation>.of(allReservations);
  var remainingGap = initialGap;
  final selectedMoves = <TradeOffMove>[];
  final movedOriginalTasks = <TaskItem>[];

  for (final task in candidates) {
    if (remainingGap <= 0 || selectedMoves.length >= 3) break;
    final minutes = task.effectiveRemainingMinutes < remainingGap
        ? task.effectiveRemainingMinutes
        : remainingGap;
    final placement = _findCombinedDestination(
      task: task,
      movedMinutes: minutes,
      sourceDay: selectedDay,
      now: localNow,
      tasks: revisedTasks,
      availability: allAvailability,
      reservations: proposedReservations,
      recoverySlots: allRecovery,
    );
    if (placement == null) continue;

    revisedTasks = [
      for (final item in revisedTasks)
        if (item.id == task.id)
          _withRemainingMinutes(item, item.effectiveRemainingMinutes - minutes)
        else
          item,
    ];
    proposedReservations = [
      ...proposedReservations,
      PlanReservation(
        taskId: task.id,
        startAt: placement,
        endAt: placement.add(Duration(minutes: minutes)),
      ),
    ];
    movedOriginalTasks.add(task);
    selectedMoves.add(
      TradeOffMove(
        taskId: task.id,
        taskTitle: task.title,
        proposedStart: placement,
        proposedEnd: placement.add(Duration(minutes: minutes)),
        movedMinutes: minutes,
        needsAgreement: task.flexibility == TaskFlexibility.needsAgreement,
      ),
    );
    remainingGap = DailyCapacity.forDay(
      day: selectedDay,
      tasks: revisedTasks,
      availability: allAvailability,
      reservations: proposedReservations,
      recoverySlots: allRecovery,
    ).overloadMinutes;
  }

  if (remainingGap > 0 || selectedMoves.length < 2) return null;
  for (final task in movedOriginalTasks) {
    final destinationDay = _dateOnly(
      selectedMoves
          .singleWhere((move) => move.taskId == task.id)
          .proposedStart
          .toLocal(),
    );
    if (!_affectedDaysAreClear(
      originalTask: task,
      destinationDay: destinationDay,
      tasks: revisedTasks,
      availability: allAvailability,
      reservations: proposedReservations,
      recoverySlots: allRecovery,
    )) {
      return null;
    }
  }

  final totalMoved = selectedMoves.fold<int>(
    0,
    (sum, move) => sum + move.movedMinutes,
  );
  final moveSummary = selectedMoves
      .map((move) {
        final date = _dateLabel(_dateOnly(move.proposedStart.toLocal()));
        return '${move.taskTitle}: ${move.movedMinutes} min to $date '
            '${_timeLabel(move.proposedStart)}–${_timeLabel(move.proposedEnd)}';
      })
      .join('  ');
  final first = selectedMoves.first;
  return TradeOffPlan(
    id: 'combined:${selectedMoves.map((move) => move.taskId).join('+')}',
    title: 'Move ${selectedMoves.length} tasks to clear the overload',
    description: moveSummary,
    taskId: first.taskId,
    taskTitle: '${selectedMoves.length} tasks',
    proposedStart: first.proposedStart,
    proposedEnd: first.proposedEnd,
    movedMinutes: totalMoved,
    needsAgreement: selectedMoves.any((move) => move.needsAgreement),
    moves: List.unmodifiable(selectedMoves),
  );
}

DateTime? _findCombinedDestination({
  required TaskItem task,
  required int movedMinutes,
  required DateTime sourceDay,
  required DateTime now,
  required List<TaskItem> tasks,
  required List<AvailabilityBlock> availability,
  required List<PlanReservation> reservations,
  required List<RecoverySlot> recoverySlots,
}) {
  final busy = <_Interval>[
    for (final item in tasks)
      if (item.status == TaskStatus.planned &&
          item.scheduledStart != null &&
          item.scheduledEnd != null)
        _Interval(item.scheduledStart!, item.scheduledEnd!),
    for (final item in reservations) _Interval(item.startAt, item.endAt),
    for (final item in recoverySlots)
      if (item.isProtected) _Interval(item.startAt, item.endAt),
    for (final block in availability)
      if (!block.isAvailable) _Interval(block.startAt, block.endAt),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final blocks = availability.where((block) => block.isAvailable).toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));
  final duration = Duration(minutes: movedMinutes);

  for (final block in blocks) {
    var cursor = _later(block.startAt, now);
    final blockEnd = _earlier(block.endAt, task.dueAt);
    while (cursor.isBefore(blockEnd)) {
      final targetDay = _dateOnly(cursor.toLocal());
      final nextDay = DateTime(
        targetDay.year,
        targetDay.month,
        targetDay.day + 1,
      );
      final segmentEnd = _earlier(blockEnd, nextDay);
      if (!DailyCapacity.sameDay(targetDay, sourceDay)) {
        final start = _firstFreeStart(
          from: cursor,
          until: segmentEnd,
          duration: duration,
          busy: busy,
        );
        if (start != null) {
          final remaining = task.effectiveRemainingMinutes - movedMinutes;
          final revisedTasks = [
            for (final item in tasks)
              if (item.id == task.id)
                _withRemainingMinutes(item, remaining)
              else
                item,
          ];
          final revisedReservations = [
            ...reservations,
            PlanReservation(
              taskId: task.id,
              startAt: start,
              endAt: start.add(duration),
            ),
          ];
          if (DailyCapacity.forDay(
                day: targetDay,
                tasks: revisedTasks,
                availability: availability,
                reservations: revisedReservations,
                recoverySlots: recoverySlots,
              ).overloadMinutes ==
              0) {
            return start;
          }
        }
      }
      cursor = nextDay;
    }
  }
  return null;
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
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Mon 12 Oct", matching the dates shown elsewhere in the app.
String _dateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

/// "9:00 AM", matching the app's 12-hour times.
String _timeLabel(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:${local.minute.toString().padLeft(2, '0')} $suffix';
}

class _Interval {
  const _Interval(this.start, this.end);
  final DateTime start;
  final DateTime end;
}
