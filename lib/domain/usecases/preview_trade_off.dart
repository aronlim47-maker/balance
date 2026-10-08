import '../enums/task_flexibility.dart';
import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/plan_reservation.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';
import 'daily_capacity.dart';
import 'generate_trade_offs.dart';

class PlanDayComparison {
  const PlanDayComparison(this.day, this.before, this.after);
  final DateTime day;
  final DailyCapacity before;
  final DailyCapacity after;
}

class TradeOffPreview {
  const TradeOffPreview({
    required this.option,
    required this.days,
    required this.protectedTitles,
    this.issue,
  });
  final TradeOffPlan option;
  final List<PlanDayComparison> days;
  final List<String> protectedTitles;
  final String? issue;
  bool get canApply =>
      issue == null &&
      !option.needsAgreement &&
      days.isNotEmpty &&
      days.every((day) => day.after.overloadMinutes == 0);
}

/// Simulates every move in a plan without writing any data. This is an
/// explanation adapter; the live RPC remains the final authority.
TradeOffPreview previewTradeOff({
  required TradeOffPlan option,
  required DateTime sourceDay,
  required List<TaskItem> tasks,
  required List<AvailabilityBlock> availability,
  required List<PlanReservation> reservations,
  required List<RecoverySlot> recoverySlots,
}) {
  final protected = [
    for (final task in tasks)
      if (task.status == TaskStatus.planned &&
          (task.isProtected || task.flexibility == TaskFlexibility.fixed))
        task.title,
  ];
  TradeOffPreview invalid(String issue) => TradeOffPreview(
    option: option,
    days: const [],
    protectedTitles: List.unmodifiable(protected),
    issue: issue,
  );
  final moves = option.allMoves;
  if (moves.isEmpty ||
      moves.map((move) => move.taskId).toSet().length != moves.length) {
    return invalid(
      'This plan contains duplicate or missing tasks. Refresh to review it.',
    );
  }
  final revisedById = <String, TaskItem>{};
  final sources = <String, TaskItem>{};
  for (final move in moves) {
    final matches = tasks.where((task) => task.id == move.taskId).toList();
    if (matches.length != 1) {
      return invalid('Refresh to review the latest tasks.');
    }
    final task = matches.single;
    final start = task.scheduledStart;
    final end = task.scheduledEnd;
    if (task.status != TaskStatus.planned ||
        task.isProtected ||
        task.flexibility == TaskFlexibility.fixed ||
        start == null ||
        end == null ||
        move.movedMinutes <= 0 ||
        move.movedMinutes > task.effectiveRemainingMinutes ||
        end.difference(start) !=
            Duration(minutes: task.effectiveRemainingMinutes) ||
        move.proposedEnd.difference(move.proposedStart) !=
            Duration(minutes: move.movedMinutes) ||
        move.proposedEnd.isAfter(task.dueAt) ||
        move.taskTitle != task.title) {
      return invalid(
        'A task move no longer matches the latest task. Refresh before confirming.',
      );
    }
    sources[task.id] = task;
    final remaining = task.effectiveRemainingMinutes - move.movedMinutes;
    revisedById[task.id] = TaskItem(
      id: task.id,
      version: task.version,
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
      scheduledStart: remaining == 0 ? null : start,
      scheduledEnd: remaining == 0
          ? null
          : start.add(Duration(minutes: remaining)),
    );
  }
  final revisedTasks = [for (final item in tasks) revisedById[item.id] ?? item];
  final revisedReservations = [
    ...reservations,
    for (final move in moves)
      PlanReservation(
        taskId: move.taskId,
        startAt: move.proposedStart,
        endAt: move.proposedEnd,
      ),
  ];
  bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) => aStart.isBefore(bEnd) && bStart.isBefore(aEnd);

  for (var index = 0; index < moves.length; index++) {
    final move = moves[index];
    final duration = Duration(minutes: move.movedMinutes);
    final insideAvailability = availability.any(
      (block) =>
          block.isAvailable &&
          !move.proposedStart.isBefore(block.startAt) &&
          !move.proposedEnd.isAfter(block.endAt),
    );
    final conflictsWithTask = revisedTasks.any(
      (item) =>
          item.status == TaskStatus.planned &&
          item.scheduledStart != null &&
          item.scheduledEnd != null &&
          overlaps(
            move.proposedStart,
            move.proposedEnd,
            item.scheduledStart!,
            item.scheduledEnd!,
          ),
    );
    final conflictsWithReservation = reservations.any(
      (reservation) => overlaps(
        move.proposedStart,
        move.proposedEnd,
        reservation.startAt,
        reservation.endAt,
      ),
    );
    final conflictsWithRecovery = recoverySlots.any(
      (slot) =>
          slot.isProtected &&
          overlaps(
            move.proposedStart,
            move.proposedEnd,
            slot.startAt,
            slot.endAt,
          ),
    );
    final conflictsWithBlockedTime = availability.any(
      (block) =>
          !block.isAvailable &&
          overlaps(
            move.proposedStart,
            move.proposedEnd,
            block.startAt,
            block.endAt,
          ),
    );
    final conflictsWithAnotherMove = moves.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          overlaps(
            move.proposedStart,
            move.proposedEnd,
            entry.value.proposedStart,
            entry.value.proposedEnd,
          ),
    );
    if (move.proposedEnd.difference(move.proposedStart) != duration ||
        !insideAvailability ||
        conflictsWithTask ||
        conflictsWithReservation ||
        conflictsWithRecovery ||
        conflictsWithBlockedTime ||
        conflictsWithAnotherMove) {
      return invalid(
        'A proposed time is no longer free. Refresh before confirming.',
      );
    }
  }
  if (moves.fold<int>(0, (sum, move) => sum + move.movedMinutes) !=
      option.movedMinutes) {
    return invalid(
      'The total moved time does not match this plan. Refresh to review it.',
    );
  }
  DateTime date(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  final days = <DateTime>{date(sourceDay)};
  void addDays(DateTime from, DateTime until) {
    for (
      var day = date(from);
      day.isBefore(until);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      days.add(day);
    }
  }

  for (final move in moves) {
    final task = sources[move.taskId]!;
    addDays(task.scheduledStart!, task.scheduledEnd!);
    addDays(move.proposedStart, move.proposedEnd);
  }
  final sorted = days.toList()..sort();
  final comparisons = [
    for (final day in sorted)
      PlanDayComparison(
        day,
        DailyCapacity.forDay(
          day: day,
          tasks: tasks,
          availability: availability,
          reservations: reservations,
          recoverySlots: recoverySlots,
        ),
        DailyCapacity.forDay(
          day: day,
          tasks: revisedTasks,
          availability: availability,
          reservations: revisedReservations,
          recoverySlots: recoverySlots,
        ),
      ),
  ];
  return TradeOffPreview(
    option: option,
    days: List.unmodifiable(comparisons),
    protectedTitles: List.unmodifiable(protected),
    issue: comparisons.any((day) => day.after.overloadMinutes > 0)
        ? 'This move does not clear the affected days. Refresh or review availability.'
        : moves.any(
                (move) =>
                    sources[move.taskId]!.flexibility ==
                    TaskFlexibility.needsAgreement,
              ) ||
              option.needsAgreement
        ? 'Agreement is required. Update the task after agreement, then refresh.'
        : null,
  );
}
