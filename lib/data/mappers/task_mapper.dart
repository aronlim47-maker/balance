import '../../domain/enums/task_flexibility.dart';
import '../../domain/enums/task_status.dart';
import '../../domain/models/task_item.dart';

abstract final class TaskMapper {
  static TaskItem fromJson(Map<String, dynamic> json) => TaskItem(
    id: json['id'] as String,
    title: json['title'] as String,
    estimatedMinutes: (json['estimated_minutes'] as num).toInt(),
    remainingMinutes: (json['remaining_minutes'] as num?)?.toInt(),
    dueAt: DateTime.parse(json['due_at'] as String),
    scheduledStart: _dateTime(json['scheduled_start']),
    scheduledEnd: _dateTime(json['scheduled_end']),
    flexibility: _flexibility(json['flexibility'] as String),
    status: _status(json['status'] as String),
    isProtected: json['is_protected'] as bool? ?? false,
    isOptional: json['is_optional'] as bool? ?? false,
  );

  static Map<String, dynamic> toInsert(TaskItem task, String userId) => {
    'user_id': userId,
    ...toUpdate(task),
    'remaining_minutes': task.effectiveRemainingMinutes,
  };

  static Map<String, dynamic> toUpdate(
    TaskItem task, {
    bool clearSchedule = false,
  }) => {
    'title': task.title.trim(),
    'estimated_minutes': task.estimatedMinutes,
    'due_at': task.dueAt.toUtc().toIso8601String(),
    'flexibility': _flexibilityValue(task.flexibility),
    'is_protected': task.isProtected,
    'is_optional': task.isOptional,
    'status': task.status.name,
    if (task.scheduledStart != null || clearSchedule)
      'scheduled_start': task.scheduledStart?.toUtc().toIso8601String(),
    if (task.scheduledEnd != null || clearSchedule)
      'scheduled_end': task.scheduledEnd?.toUtc().toIso8601String(),
  };

  static DateTime? _dateTime(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  static TaskFlexibility _flexibility(String value) => switch (value) {
    'fixed' => TaskFlexibility.fixed,
    'needs_agreement' => TaskFlexibility.needsAgreement,
    _ => TaskFlexibility.flexible,
  };

  static String _flexibilityValue(TaskFlexibility value) => switch (value) {
    TaskFlexibility.fixed => 'fixed',
    TaskFlexibility.flexible => 'flexible',
    TaskFlexibility.needsAgreement => 'needs_agreement',
  };

  static TaskStatus _status(String value) => switch (value) {
    'completed' => TaskStatus.completed,
    'cancelled' => TaskStatus.cancelled,
    _ => TaskStatus.planned,
  };
}
