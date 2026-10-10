import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/recovery_slot.dart';
import '../models/task_item.dart';

/// A stretch of available time with nothing planned in it.
class FreeWindow {
  const FreeWindow(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int get minutes => end.difference(start).inMinutes;
}

/// Free time on [day] that a recovery slot could use: available blocks minus
/// blocked time, scheduled planned work and other recovery slots.
///
/// Mirrors the server rule that recovery must sit inside available time without
/// overlapping planned work, so a suggested window can be saved as is. Windows
/// shorter than [minMinutes] are dropped. When [now] falls on [day], time that
/// has already passed is removed.
List<FreeWindow> freeWindowsOn(
  DateTime day, {
  required List<AvailabilityBlock> availability,
  required List<TaskItem> tasks,
  required List<RecoverySlot> recovery,
  String? exceptSlotId,
  DateTime? now,
  int minMinutes = 15,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  var windows = <FreeWindow?>[
    for (final block in availability)
      if (block.isAvailable)
        _clip(block.startAt, block.endAt, dayStart, dayEnd),
  ].whereType<FreeWindow>().toList();
  windows = _merge(windows);

  final busy = <FreeWindow>[
    for (final block in availability)
      if (!block.isAvailable)
        FreeWindow(block.startAt.toLocal(), block.endAt.toLocal()),
    for (final task in tasks)
      if (task.status == TaskStatus.planned &&
          task.scheduledStart != null &&
          task.scheduledEnd != null)
        FreeWindow(
          task.scheduledStart!.toLocal(),
          task.scheduledEnd!.toLocal(),
        ),
    for (final slot in recovery)
      if (slot.id != exceptSlotId)
        FreeWindow(slot.startAt.toLocal(), slot.endAt.toLocal()),
    if (now != null && now.isAfter(dayStart))
      FreeWindow(dayStart, now.toLocal()),
  ];
  for (final b in busy) {
    windows = [for (final w in windows) ..._subtract(w, b)];
  }
  return windows.where((w) => w.minutes >= minMinutes).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

FreeWindow? _clip(DateTime start, DateTime end, DateTime from, DateTime to) {
  final s = start.toLocal().isBefore(from) ? from : start.toLocal();
  final e = end.toLocal().isAfter(to) ? to : end.toLocal();
  return e.isAfter(s) ? FreeWindow(s, e) : null;
}

List<FreeWindow> _merge(List<FreeWindow> windows) {
  windows.sort((a, b) => a.start.compareTo(b.start));
  final merged = <FreeWindow>[];
  for (final w in windows) {
    if (merged.isNotEmpty && !w.start.isAfter(merged.last.end)) {
      final last = merged.removeLast();
      merged.add(
        FreeWindow(last.start, w.end.isAfter(last.end) ? w.end : last.end),
      );
    } else {
      merged.add(w);
    }
  }
  return merged;
}

List<FreeWindow> _subtract(FreeWindow w, FreeWindow b) {
  if (!b.end.isAfter(w.start) || !b.start.isBefore(w.end)) return [w];
  return [
    if (b.start.isAfter(w.start)) FreeWindow(w.start, b.start),
    if (b.end.isBefore(w.end)) FreeWindow(b.end, w.end),
  ];
}
