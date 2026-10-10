import 'package:timezone/timezone.dart' as tz;

import '../enums/task_status.dart';
import '../models/availability_block.dart';
import '../models/task_item.dart';
import 'daily_capacity.dart';

class ReminderPreferences {
  const ReminderPreferences({
    this.enabled = false,
    this.leadMinutes = 30,
    this.quietEnabled = true,
    this.quietStart = 22 * 60,
    this.quietEnd = 8 * 60,
    this.overloadAlerts = false,
    this.overloadAt = 20 * 60,
  });
  final bool enabled;

  /// Warn the evening before a day whose planned work exceeds its available
  /// time. Off by default.
  final bool overloadAlerts;

  /// Minute of the day (local) for overload alerts; default 8:00 PM.
  final int overloadAt;
  final int leadMinutes;
  final bool quietEnabled;
  final int quietStart;
  final int quietEnd;

  bool get isValid =>
      [15, 30, 60, 1440].contains(leadMinutes) &&
      quietStart >= 0 &&
      quietStart < 1440 &&
      quietEnd >= 0 &&
      quietEnd < 1440 &&
      overloadAt >= 0 &&
      overloadAt < 1440 &&
      (!quietEnabled || quietStart != quietEnd);

  ReminderPreferences copyWith({
    bool? enabled,
    int? leadMinutes,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
    bool? overloadAlerts,
    int? overloadAt,
  }) => ReminderPreferences(
    enabled: enabled ?? this.enabled,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
    overloadAlerts: overloadAlerts ?? this.overloadAlerts,
    overloadAt: overloadAt ?? this.overloadAt,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'lead': leadMinutes,
    'quiet': quietEnabled,
    'start': quietStart,
    'end': quietEnd,
    'overload': overloadAlerts,
    'overloadAt': overloadAt,
  };

  factory ReminderPreferences.fromJson(Map<String, dynamic> json) {
    final result = ReminderPreferences(
      enabled: json['enabled'] == true,
      leadMinutes: json['lead'] is int ? json['lead'] as int : 30,
      quietEnabled: json['quiet'] != false,
      quietStart: json['start'] is int ? json['start'] as int : 1320,
      quietEnd: json['end'] is int ? json['end'] as int : 480,
      overloadAlerts: json['overload'] == true,
      overloadAt: json['overloadAt'] is int ? json['overloadAt'] as int : 1200,
    );
    return result.isValid ? result : const ReminderPreferences();
  }
}

class TaskReminder {
  const TaskReminder(this.taskId, this.at);
  final String taskId;
  final tz.TZDateTime at;
}

/// Deadline reminders only: this never changes a task or a confirmed plan.
List<TaskReminder> planTaskReminders(
  List<TaskItem> tasks,
  ReminderPreferences preferences,
  DateTime now,
  tz.Location location,
) {
  if (!preferences.enabled || !preferences.isValid) return [];
  final seen = <String>{};
  final result = <TaskReminder>[];
  for (final task in tasks) {
    if (task.id.isEmpty ||
        task.status != TaskStatus.planned ||
        task.effectiveRemainingMinutes <= 0 ||
        !seen.add(task.id)) {
      continue;
    }
    final at = tz.TZDateTime.from(
      task.dueAt.subtract(Duration(minutes: preferences.leadMinutes)),
      location,
    );
    if (!at.isAfter(now)) continue;
    if (_inQuietHours(at, preferences)) continue;
    result.add(TaskReminder(task.id, at));
  }
  result.sort((a, b) {
    final time = a.at.compareTo(b.at);
    return time == 0 ? a.taskId.compareTo(b.taskId) : time;
  });
  // Stay below iOS's pending notification limit and avoid overwhelming users.
  return result.take(50).toList(growable: false);
}

bool _inQuietHours(DateTime at, ReminderPreferences preferences) {
  final minute = at.hour * 60 + at.minute;
  final start = preferences.quietStart;
  final end = preferences.quietEnd;
  final quiet = start < end
      ? minute >= start && minute < end
      : minute >= start || minute < end;
  return preferences.quietEnabled && quiet;
}

/// A warning, sent the evening before, that [day] has more planned work than
/// available time.
class OverloadAlert {
  const OverloadAlert(this.day, this.overloadMinutes, this.at);
  final DateTime day;
  final int overloadMinutes;
  final tz.TZDateTime at;
}

/// Overload alerts for the next [days] local dates. Read-only: it never moves
/// a task. A day whose evening-before time has passed, or falls in quiet
/// hours, gets no alert.
List<OverloadAlert> planOverloadAlerts(
  List<TaskItem> tasks,
  List<AvailabilityBlock> availability,
  ReminderPreferences preferences,
  DateTime now,
  tz.Location location, {
  int days = 7,
}) {
  if (!preferences.overloadAlerts || !preferences.isValid) return [];
  final today = DateTime(now.year, now.month, now.day);
  final result = <OverloadAlert>[];
  for (var i = 1; i <= days; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    final overload = DailyCapacity.forDay(
      day: day,
      tasks: tasks,
      availability: availability,
    ).overloadMinutes;
    if (overload <= 0) continue;
    final at = tz.TZDateTime(
      location,
      day.year,
      day.month,
      day.day - 1,
      preferences.overloadAt ~/ 60,
      preferences.overloadAt % 60,
    );
    if (!at.isAfter(now) || _inQuietHours(at, preferences)) continue;
    result.add(OverloadAlert(day, overload, at));
  }
  return result;
}
