import 'package:timezone/timezone.dart' as tz;

import '../enums/task_status.dart';
import '../models/task_item.dart';

class ReminderPreferences {
  const ReminderPreferences({
    this.enabled = false,
    this.leadMinutes = 30,
    this.quietEnabled = true,
    this.quietStart = 22 * 60,
    this.quietEnd = 8 * 60,
  });
  final bool enabled;
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
      (!quietEnabled || quietStart != quietEnd);

  ReminderPreferences copyWith({
    bool? enabled,
    int? leadMinutes,
    bool? quietEnabled,
    int? quietStart,
    int? quietEnd,
  }) => ReminderPreferences(
    enabled: enabled ?? this.enabled,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    quietEnabled: quietEnabled ?? this.quietEnabled,
    quietStart: quietStart ?? this.quietStart,
    quietEnd: quietEnd ?? this.quietEnd,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'lead': leadMinutes,
    'quiet': quietEnabled,
    'start': quietStart,
    'end': quietEnd,
  };

  factory ReminderPreferences.fromJson(Map<String, dynamic> json) {
    final result = ReminderPreferences(
      enabled: json['enabled'] == true,
      leadMinutes: json['lead'] is int ? json['lead'] as int : 30,
      quietEnabled: json['quiet'] != false,
      quietStart: json['start'] is int ? json['start'] as int : 1320,
      quietEnd: json['end'] is int ? json['end'] as int : 480,
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
    final minute = at.hour * 60 + at.minute;
    final start = preferences.quietStart;
    final end = preferences.quietEnd;
    final quiet = start < end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
    if (preferences.quietEnabled && quiet) continue;
    result.add(TaskReminder(task.id, at));
  }
  result.sort((a, b) {
    final time = a.at.compareTo(b.at);
    return time == 0 ? a.taskId.compareTo(b.taskId) : time;
  });
  // Stay below iOS's pending notification limit and avoid overwhelming users.
  return result.take(50).toList(growable: false);
}
