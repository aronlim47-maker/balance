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

/// Simulates the existing single-task RPC semantics without writing any data.
/// This is an explanation adapter, not a new recommendation/scoring algorithm.
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
  final matches = tasks.where((task) => task.id == option.taskId).toList();
  if (matches.length != 1) return invalid('Refresh to review the latest task.');
  final task = matches.single;
  final start = task.scheduledStart;
  final end = task.scheduledEnd;
  if (task.status != TaskStatus.planned ||
      task.isProtected ||
      task.flexibility == TaskFlexibility.fixed ||
      start == null ||
      end == null ||
      option.movedMinutes <= 0 ||
      option.movedMinutes > task.effectiveRemainingMinutes ||
      end.difference(start) !=
          Duration(minutes: task.effectiveRemainingMinutes) ||
      option.proposedEnd.difference(option.proposedStart) !=
          Duration(minutes: option.movedMinutes) ||
      option.proposedEnd.isAfter(task.dueAt)) {
    return invalid(
      'This move no longer matches the task. Refresh before confirming.',
    );
  }
  final remaining = task.effectiveRemainingMinutes - option.movedMinutes;
  final revised = TaskItem(
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
  final revisedTasks = [
    for (final item in tasks) item.id == task.id ? revised : item,
  ];
  final revisedReservations = [
    ...reservations,
    PlanReservation(
      taskId: task.id,
      startAt: option.proposedStart,
      endAt: option.proposedEnd,
    ),
  ];
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

  addDays(start, end);
  addDays(option.proposedStart, option.proposedEnd);
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
        : task.flexibility == TaskFlexibility.needsAgreement ||
              option.needsAgreement
        ? 'Agreement is required. Update the task after agreement, then refresh.'
        : null,
  );
}
