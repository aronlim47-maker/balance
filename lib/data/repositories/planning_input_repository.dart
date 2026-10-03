import '../../domain/models/local_date.dart';
import '../../domain/models/planning_data.dart';

/// Proposed write contract for Tan and Matthew; not wired into the existing UI.
/// Implementations obtain user_id from the session and validate owned links.
/// Reuse requestId on retry; conflicting payloads for the same key must fail.
/// Deduplication applies while the original input row is retained unchanged.
abstract interface class PlanningInputRepository {
  Future<void> setTaskCategory(String taskId, LoadCategory category);
  Future<void> saveReviewEnergy({
    required LocalDate date,
    required EnergyLevel? mental,
    required EnergyLevel? physical,
  });
  Future<ExerciseLog> confirmExercise({
    required String requestId,
    required DateTime occurredAt,
    required int durationMinutes,
    String? taskId,
    String? intensity,
  });
  Future<SocialEvent> confirmSocialEvent({
    required String requestId,
    required DateTime startAt,
    required DateTime endAt,
    required EnergyLevel pressureLevel,
    required bool? hasConflict,
    String? taskId,
  });
  Future<void> setSocialWeekResponse({
    required LocalDate weekStart,
    required bool noSocialCommitments,
  });
  Future<ReflectionEntry> saveReflection({
    required String requestId,
    required LocalDate date,
    required String content,
  });

  /// Uses the existing verified RPC. The server determines the review date.
  /// requestId/localDate are retained for source compatibility, not deduplication.
  /// Do not treat this method as an idempotent raw-input insert.
  Future<void> acknowledgeOverload({
    required String requestId,
    required String taskId,
    required LocalDate localDate,
  });
}
