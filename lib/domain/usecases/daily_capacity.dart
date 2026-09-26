import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/plan_reservation.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';

class DailyCapacity {
  const DailyCapacity({
    required this.plannedMinutes,
    required this.availableMinutes,
    required this.workMinutes,
    required this.recoveryMinutes,
    required this.overloadMinutes,
  });

  final int plannedMinutes;
  final int availableMinutes;
  final int workMinutes;
  final int recoveryMinutes;
  final int overloadMinutes;

  static DailyCapacity forDay({
    required DateTime day,
    required Iterable<TaskItem> tasks,
    required Iterable<AvailabilityBlock> availability,
    Iterable<PlanReservation> reservations = const [],
    Iterable<RecoverySlot> recoverySlots = const [],
  }) {
    final localDay = DateTime(day.year, day.month, day.day);
    final availableMinutes = availability
        .where((block) => block.isAvailable)
        .fold<int>(
          0,
          (total, block) =>
              total + overlapMinutes(block.startAt, block.endAt, localDay),
        );
    final taskMinutes = tasks
        .where((task) => task.status == TaskStatus.planned)
        .fold<int>(0, (total, task) {
          if (task.scheduledStart != null && task.scheduledEnd != null) {
            return total +
                overlapMinutes(
                  task.scheduledStart!,
                  task.scheduledEnd!,
                  localDay,
                );
          }
          return total +
              (sameDay(task.dueAt.toLocal(), localDay)
                  ? task.effectiveRemainingMinutes
                  : 0);
        });
    final reservedMinutes = reservations.fold<int>(
      0,
      (total, item) =>
          total + overlapMinutes(item.startAt, item.endAt, localDay),
    );
    final recoveryMinutes = recoverySlots
        .where((slot) => slot.isProtected)
        .fold<int>(
          0,
          (total, slot) =>
              total + overlapMinutes(slot.startAt, slot.endAt, localDay),
        );
    final workMinutes = taskMinutes + reservedMinutes;
    final localEnd = DateTime(localDay.year, localDay.month, localDay.day + 1);
    final cutoffs = <DateTime>{
      localEnd,
      for (final task in tasks)
        if (task.status == TaskStatus.planned &&
            task.scheduledStart == null &&
            sameDay(task.dueAt.toLocal(), localDay))
          task.dueAt.toLocal(),
    };
    var overloadMinutes = 0;
    for (final cutoff in cutoffs) {
      final availableByCutoff = availability
          .where((block) => block.isAvailable)
          .fold<int>(
            0,
            (total, block) =>
                total +
                _overlapUntil(block.startAt, block.endAt, localDay, cutoff),
          );
      final scheduledByCutoff = tasks
          .where((task) => task.status == TaskStatus.planned)
          .fold<int>(0, (total, task) {
            if (task.scheduledStart != null && task.scheduledEnd != null) {
              return total +
                  _overlapUntil(
                    task.scheduledStart!,
                    task.scheduledEnd!,
                    localDay,
                    cutoff,
                  );
            }
            return total +
                (sameDay(task.dueAt.toLocal(), localDay) &&
                        !task.dueAt.toLocal().isAfter(cutoff)
                    ? task.effectiveRemainingMinutes
                    : 0);
          });
      final reservedByCutoff = reservations.fold<int>(
        0,
        (total, item) =>
            total + _overlapUntil(item.startAt, item.endAt, localDay, cutoff),
      );
      final recoveryByCutoff = recoverySlots
          .where((slot) => slot.isProtected)
          .fold<int>(
            0,
            (total, slot) =>
                total +
                _overlapUntil(slot.startAt, slot.endAt, localDay, cutoff),
          );
      final gap =
          scheduledByCutoff +
          reservedByCutoff +
          recoveryByCutoff -
          availableByCutoff;
      if (gap > overloadMinutes) overloadMinutes = gap;
    }
    return DailyCapacity(
      plannedMinutes: workMinutes + recoveryMinutes,
      availableMinutes: availableMinutes,
      workMinutes: workMinutes,
      recoveryMinutes: recoveryMinutes,
      overloadMinutes: overloadMinutes,
    );
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool overlapsDay(DateTime start, DateTime end, DateTime day) =>
      overlapMinutes(start, end, day) > 0;

  static int overlapMinutes(DateTime start, DateTime end, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final clippedStart = localStart.isAfter(dayStart) ? localStart : dayStart;
    final clippedEnd = localEnd.isBefore(dayEnd) ? localEnd : dayEnd;
    return clippedEnd.isAfter(clippedStart)
        ? clippedEnd.difference(clippedStart).inMinutes
        : 0;
  }

  static int _overlapUntil(
    DateTime start,
    DateTime end,
    DateTime day,
    DateTime cutoff,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final clippedStart = localStart.isAfter(dayStart) ? localStart : dayStart;
    final clippedEnd = localEnd.isBefore(cutoff) ? localEnd : cutoff;
    return clippedEnd.isAfter(clippedStart)
        ? clippedEnd.difference(clippedStart).inMinutes
        : 0;
  }
}
