import 'dart:math' as math;

import '../enums/task_flexibility.dart';
import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';
import 'daily_capacity.dart';

/// Why Council could not find a safe move, in the order a student should read.
enum NoPlanReasonKind {
  noFreeTime,
  dueBeforeFreeTime,
  flexibleUnscheduled,
  noLaterFreeTime,
  needsAgreement,
  protectedStays,
}

class NoPlanReason {
  const NoPlanReason(this.kind, this.message, {this.taskId});

  final NoPlanReasonKind kind;
  final String message;
  final String? taskId;
}

/// Plain-language explanation of an overloaded day with no safe plan.
/// Display only: it never proposes or saves a change.
class NoPlanExplanation {
  const NoPlanExplanation({
    required this.gapMinutes,
    required this.extraWorkMinutes,
    required this.dueBeforeFreeTimeMinutes,
    required this.reasons,
  });

  /// The day's overload, the same number as the capacity card.
  final int gapMinutes;

  /// Planned minutes beyond all free time on the day.
  final int extraWorkMinutes;

  /// The rest of the gap: work due before enough free time has started.
  final int dueBeforeFreeTimeMinutes;
  final List<NoPlanReason> reasons;

  bool get suggestsTasks => reasons.any(
    (reason) =>
        reason.kind == NoPlanReasonKind.flexibleUnscheduled ||
        reason.kind == NoPlanReasonKind.needsAgreement ||
        reason.kind == NoPlanReasonKind.protectedStays,
  );

  bool get suggestsFreeTime => reasons.any(
    (reason) =>
        reason.kind == NoPlanReasonKind.noFreeTime ||
        reason.kind == NoPlanReasonKind.dueBeforeFreeTime ||
        reason.kind == NoPlanReasonKind.noLaterFreeTime,
  );
}

/// Explains why no trade-off exists for [day]. Mirrors the rules Council uses:
/// protected and fixed work never moves, agreement-dependent work needs
/// agreement first, and only flexible work that already has a time on the
/// day can be moved to free time before its deadline.
NoPlanExplanation explainNoFeasiblePlan({
  required DateTime day,
  required Iterable<TaskItem> tasks,
  required Iterable<AvailabilityBlock> availability,
  required DailyCapacity capacity,
  Iterable<RecoverySlot> recoverySlots = const [],
}) {
  final selectedDay = DateTime(day.year, day.month, day.day);
  final gap = capacity.overloadMinutes;
  final extra = math.max(
    0,
    capacity.plannedMinutes - capacity.availableMinutes,
  );
  final dueBefore = math.max(0, gap - extra);
  final dayTasks = tasks.where((task) => _isOnDay(task, selectedDay)).toList()
    ..sort((a, b) => _taskTime(a).compareTo(_taskTime(b)));

  final reasons = <NoPlanReason>[];
  if (capacity.availableMinutes == 0) {
    reasons.add(
      const NoPlanReason(
        NoPlanReasonKind.noFreeTime,
        'No free time is added for this day. Add your real availability on '
        'Today so Council has time to work with.',
      ),
    );
  } else if (dueBefore > 0) {
    final firstFree = _firstFreeStart(availability, selectedDay);
    reasons.add(
      NoPlanReason(
        NoPlanReasonKind.dueBeforeFreeTime,
        firstFree == null
            ? '$dueBefore min of work is due before enough free time is '
                  'available.'
            : '$dueBefore min of work is due before your free time starts '
                  '(${_clock(firstFree)}). Add earlier free time or ask for a '
                  'later deadline.',
      ),
    );
  }

  for (final task in dayTasks) {
    if (_isMovableKind(task) && task.scheduledStart == null) {
      reasons.add(
        NoPlanReason(
          NoPlanReasonKind.flexibleUnscheduled,
          '"${task.title}" (${task.effectiveRemainingMinutes} min) has no time '
          'on this day, so Council cannot move it. Give it a start time first.',
          taskId: task.id,
        ),
      );
    }
  }

  final scheduledMovable = dayTasks
      .where((task) => _isMovableKind(task) && task.scheduledStart != null)
      .take(3);
  final dayEnd = DateTime(
    selectedDay.year,
    selectedDay.month,
    selectedDay.day + 1,
  );
  for (final task in scheduledMovable) {
    // Name protected rest that sits in the free time Council could have used,
    // so the student knows what to change instead of a generic message.
    final blocking =
        recoverySlots
            .where(
              (slot) =>
                  slot.isProtected &&
                  !slot.startAt.isBefore(dayEnd) &&
                  slot.startAt.isBefore(task.dueAt) &&
                  availability.any(
                    (block) =>
                        block.isAvailable &&
                        block.startAt.isBefore(slot.endAt) &&
                        block.endAt.isAfter(slot.startAt),
                  ),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    reasons.add(
      NoPlanReason(
        NoPlanReasonKind.noLaterFreeTime,
        blocking.isEmpty
            ? 'No free time was found for "${task.title}" before it is due. '
                  'Add free time on another day before its deadline.'
            : '"${task.title}" does not fit before it is due because protected '
                  'recovery time (${_day(blocking.first.startAt)}, '
                  '${_clock(blocking.first.startAt)}) uses free time it needs. '
                  'Remove or move that slot in Sanctuary, or add free time.',
        taskId: task.id,
      ),
    );
  }

  for (final task in dayTasks) {
    if (!task.isProtected &&
        task.flexibility == TaskFlexibility.needsAgreement) {
      reasons.add(
        NoPlanReason(
          NoPlanReasonKind.needsAgreement,
          '"${task.title}" needs agreement before it can move.',
          taskId: task.id,
        ),
      );
    }
  }

  for (final task in dayTasks) {
    if (task.isProtected || task.flexibility == TaskFlexibility.fixed) {
      reasons.add(
        NoPlanReason(
          NoPlanReasonKind.protectedStays,
          '"${task.title}" (${task.effectiveRemainingMinutes} min) is '
          '${task.isProtected ? 'protected' : 'fixed'}, so it stays where it '
          'is.',
          taskId: task.id,
        ),
      );
    }
  }

  if (reasons.isEmpty) {
    reasons.add(
      const NoPlanReason(
        NoPlanReasonKind.noLaterFreeTime,
        'No move fits before the deadlines. Add free time on another day or '
        'ask for a deadline change.',
      ),
    );
  }

  return NoPlanExplanation(
    gapMinutes: gap,
    extraWorkMinutes: extra,
    dueBeforeFreeTimeMinutes: dueBefore,
    reasons: List.unmodifiable(reasons),
  );
}

bool _isMovableKind(TaskItem task) =>
    !task.isProtected && task.flexibility == TaskFlexibility.flexible;

bool _isOnDay(TaskItem task, DateTime day) {
  if (task.status != TaskStatus.planned) return false;
  final start = task.scheduledStart;
  final end = task.scheduledEnd;
  if (start != null && end != null) {
    return DailyCapacity.overlapsDay(start, end, day);
  }
  return DailyCapacity.sameDay(task.dueAt.toLocal(), day);
}

DateTime _taskTime(TaskItem task) =>
    (task.scheduledStart ?? task.dueAt).toLocal();

DateTime? _firstFreeStart(
  Iterable<AvailabilityBlock> availability,
  DateTime day,
) {
  final starts =
      availability
          .where(
            (block) =>
                block.isAvailable &&
                DailyCapacity.overlapsDay(block.startAt, block.endAt, day),
          )
          .map((block) {
            final start = block.startAt.toLocal();
            return start.isBefore(day) ? day : start;
          })
          .toList()
        ..sort();
  return starts.isEmpty ? null : starts.first;
}

String _clock(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
}

String _day(DateTime time) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
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
  final local = time.toLocal();
  return '${weekdays[local.weekday - 1]} ${local.day} ${months[local.month - 1]}';
}
