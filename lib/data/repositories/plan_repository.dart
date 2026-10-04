import '../../domain/models/plan_change.dart';
import '../../domain/models/plan_reservation.dart';

class PlanMove {
  const PlanMove({
    required this.taskId,
    required this.proposedStart,
    required this.proposedEnd,
    required this.movedMinutes,
    required this.expectedTaskVersion,
  });

  final String taskId;
  final DateTime proposedStart;
  final DateTime proposedEnd;
  final int movedMinutes;
  final int expectedTaskVersion;

  Map<String, dynamic> toJson() => {
    'task_id': taskId,
    'proposed_start': proposedStart.toUtc().toIso8601String(),
    'proposed_end': proposedEnd.toUtc().toIso8601String(),
    'moved_minutes': movedMinutes,
    'expected_task_version': expectedTaskVersion,
  };
}

abstract interface class PlanRepository {
  Future<List<PlanChange>> fetchPlanChanges();
  Future<List<PlanReservation>> fetchPlanReservations();
  Future<int> calculateDayOverload(DateTime day);
  Future<bool> hasWarCouncilMigration();
  Future<PlanChange> confirm({
    required List<PlanMove> moves,
    DateTime? recoveryStart,
    DateTime? recoveryEnd,
    Map<String, dynamic> consequences = const <String, dynamic>{},
  });
  Future<void> undo(String changeId);
}
