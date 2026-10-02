import '../enums/task_flexibility.dart';
import '../enums/load_category.dart';
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
    this.protectedCommitmentType,
    this.isOptional = false,
    this.loadCategory,
    this.remainingMinutes,
    this.scheduledStart,
    this.scheduledEnd,
    this.version = 1,
  });
  final String id;
  final int version;
  final String title;
  final int estimatedMinutes;
  final DateTime dueAt;
  final TaskFlexibility flexibility;
  final TaskStatus status;
  final bool isProtected;

  /// work_shift, family_duty or sleep_minimum for a protected commitment.
  final String? protectedCommitmentType;
  final bool isOptional;
  final LoadCategory? loadCategory;
  final int? remainingMinutes;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;

  int get effectiveRemainingMinutes => remainingMinutes ?? estimatedMinutes;

  /// Keep the work already allocated outside the remaining task unchanged.
  int remainingAfterEstimate(int estimate) =>
      effectiveRemainingMinutes + estimate - estimatedMinutes;

  TaskItem withVersion(int value) => TaskItem(
    id: id,
    title: title,
    estimatedMinutes: estimatedMinutes,
    dueAt: dueAt,
    flexibility: flexibility,
    status: status,
    isProtected: isProtected,
    protectedCommitmentType: protectedCommitmentType,
    isOptional: isOptional,
    loadCategory: loadCategory,
    remainingMinutes: remainingMinutes,
    scheduledStart: scheduledStart,
    scheduledEnd: scheduledEnd,
    version: value,
  );
}
