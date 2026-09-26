import '../enums/task_flexibility.dart';
import '../enums/task_status.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.estimatedMinutes,
    required this.dueAt,
    this.flexibility = TaskFlexibility.flexible,
    this.status = TaskStatus.planned,
    this.isProtected = false,
    this.isOptional = false,
    this.remainingMinutes,
    this.scheduledStart,
    this.scheduledEnd,
  });
  final String id;
  final String title;
  final int estimatedMinutes;
  final DateTime dueAt;
  final TaskFlexibility flexibility;
  final TaskStatus status;
  final bool isProtected;
  final bool isOptional;
  final int? remainingMinutes;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  int get effectiveRemainingMinutes => remainingMinutes ?? estimatedMinutes;
}
