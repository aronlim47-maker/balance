import 'dart:math' as math;

import '../enums/task_flexibility.dart';
import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';
import 'daily_capacity.dart';

/// Why Council could not find a safe move, in the order a student should read.
enum NoPlanReasonKind {
  dayPassed,
  noFreeTime,
  dueBeforeFreeTime,
  noOtherDay,
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
        reason.kind == NoPlanReasonKind.noOtherDay ||
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
/// agreement first, and flexible work (scheduled on the day, or unscheduled and
/// due on it) can move, whole or in part, to free time on another day before
/// its deadline.
NoPlanExplanation explainNoFeasiblePlan({
  required DateTime day,
  required Iterable<TaskItem> tasks,
  required Iterable<AvailabilityBlock> availability,
  required DailyCapacity capacity,
  Iterable<RecoverySlot> recoverySlots = const [],
  DateTime? now,
}) {
  final selectedDay = DateTime(day.year, day.month, day.day);
  final gap = capacity.overloadMinutes;
  final extra = math.max(
    0,
    capacity.plannedMinutes - capacity.availableMinutes,
  );
  final dueBefore = math.max(0, gap - extra);

  // Council never plans a past day, so say that instead of listing reasons
  // about free time that no longer matter.
  if (now != null) {
    final local = now.toLocal();
    if (selectedDay.isBefore(DateTime(local.year, local.month, local.day))) {
      return NoPlanExplanation(
        gapMinutes: gap,
        extraWorkMinutes: extra,
        dueBeforeFreeTimeMinutes: dueBefore,
        reasons: const [
          NoPlanReason(
            NoPlanReasonKind.dayPassed,
            'This day has already passed, so Council cannot change it. '
            'Plans start from today: open today or a later day.',
          ),
        ],
      );
    }
  }
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

  final localNow = (now ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final dayEnd = DateTime(
    selectedDay.year,
    selectedDay.month,
    selectedDay.day + 1,
  );
  for (final task in dayTasks.where(_isMovableKind).take(3)) {
    if (!_hasOtherDay(task, selectedDay, today, localNow)) {
      reasons.add(
        NoPlanReason(
          NoPlanReasonKind.noOtherDay,
          '"${task.title}" (${task.effectiveRemainingMinutes} min) is due on '
          'this day, so there is no other day to move it to. Ask for a later '
          'deadline, or edit it if it can take less time.',
          taskId: task.id,
        ),
      );
      continue;
    }
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
            // Other days may have some free time, just not enough (D23).
            ? 'Not enough free time was found for "${task.title}" on other '
                  'days before it is due. Add free time on another day before '
                  'its deadline.'
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
    !task.isProtected &&
    task.flexibility == TaskFlexibility.flexible &&
    task.effectiveRemainingMinutes > 0;

/// Whether any day other than [day], from today up to the deadline, could
/// still receive part of [task].
bool _hasOtherDay(
  TaskItem task,
  DateTime day,
  DateTime today,
  DateTime localNow,
) {
  final due = task.dueAt.toLocal();
  if (!due.isAfter(localNow)) return false;
  for (
    var candidate = today;
    candidate.isBefore(due);
    candidate = DateTime(candidate.year, candidate.month, candidate.day + 1)
  ) {
    if (!DailyCapacity.sameDay(candidate, day)) return true;
  }
  return false;
}

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
  // Rows from the server are UTC; show the phone's local time.
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
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
