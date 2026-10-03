import '../../domain/models/local_date.dart';
import '../../domain/models/planning_data.dart';

abstract final class PlanningDataMapper {
  static WorldStatusSettings worldStatusSettings(Map<String, dynamic> row) =>
      WorldStatusSettings(
        userId: row['user_id'] as String,
        movementTrackingEnabled: row['movement_tracking_enabled'] as bool,
        movementTargetDays: (row['movement_target_days'] as num).toInt(),
        targetRecoveryMinutes: (row['target_recovery_minutes'] as num).toInt(),
        targetSocialMinutesWeek: (row['target_social_minutes_week'] as num)
            .toInt(),
        formulaVersion: row['formula_version'] as String,
      );
  static ExerciseLog exerciseLog(Map<String, dynamic> row) => ExerciseLog(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    taskId: row['task_id'] as String?,
    occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
    durationMinutes: (row['duration_minutes'] as num).toInt(),
    intensity: row['intensity'] as String?,
    source: row['source'] as String,
    requestId: row['request_id'] as String? ?? row['id'] as String,
  );
  static SocialEvent socialEvent(Map<String, dynamic> row) => SocialEvent(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    taskId: row['task_id'] as String?,
    startAt: DateTime.parse(row['start_at'] as String).toUtc(),
    endAt: DateTime.parse(row['end_at'] as String).toUtc(),
    pressureLevel: EnergyLevel.values.byName(row['pressure_level'] as String),
    hasConflict: row['has_conflict'] as bool?,
    requestId: row['request_id'] as String? ?? row['id'] as String,
  );
  static SocialWeekResponse socialWeekResponse(Map<String, dynamic> row) =>
      SocialWeekResponse(
        userId: row['user_id'] as String,
        weekStart: LocalDate.parse(row['week_start'] as String),
        noSocialCommitments: row['no_commitments'] as bool,
      );
  static ReflectionEntry reflectionEntry(Map<String, dynamic> row) =>
      ReflectionEntry(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        localDate: row['local_date'] == null
            ? null
            : LocalDate.parse(row['local_date'] as String),
        content: row['body'] as String,
        requestId: row['request_id'] as String? ?? row['id'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      );
  static WorldStatusSnapshot worldStatusSnapshot(Map<String, dynamic> row) =>
      WorldStatusSnapshot(
        userId: row['user_id'] as String,
        localDate: LocalDate.parse(row['local_date'] as String),
        mentalScore: (row['mental_score'] as num?)?.toDouble(),
        timeScore: (row['time_score'] as num?)?.toDouble(),
        physicalScore: (row['physical_score'] as num?)?.toDouble(),
        socialScore: (row['social_score'] as num?)?.toDouble(),
        errandsScore: (row['errands_score'] as num?)?.toDouble(),
        totalScore: (row['total_score'] as num?)?.toInt(),
        knownDimensions: List<String>.unmodifiable(
          (row['known_dimensions'] as List).cast<String>(),
        ),
        coverage: (row['coverage'] as num).toDouble(),
        trend: switch (row['trend']) {
          'rising' => WorldStatusTrend.rising,
          'stable' => WorldStatusTrend.stable,
          'easing' => WorldStatusTrend.easing,
          'not_enough_history' => WorldStatusTrend.notEnoughHistory,
          _ => throw FormatException('Unknown trend'),
        },
        formulaVersion: row['formula_version'] as String,
        computedAt: DateTime.parse(row['computed_at'] as String).toUtc(),
      );
  static AchievementDefinition achievementDefinition(
    Map<String, dynamic> row,
  ) => AchievementDefinition(
    achievementKey: row['achievement_key'] as String,
    practicalName: row['practical_name'] as String,
    rpgName: row['rpg_name'] as String,
    unlockCondition: row['condition_text'] as String,
    ruleVersion: row['rule_version'] as String,
  );
  static PlanningEvent planningEvent(Map<String, dynamic> row) => PlanningEvent(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    eventKey: row['source_key'] as String,
    eventType: row['event_type'] as String,
    occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
    evidence: Map<String, dynamic>.unmodifiable(
      row['evidence'] as Map<String, dynamic>,
    ),
  );
  static AchievementAward achievementAward(Map<String, dynamic> row) =>
      AchievementAward(
        userId: row['user_id'] as String,
        achievementKey: row['achievement_key'] as String,
        ruleVersion: row['rule_version'] as String,
        sourceEventId: row['source_event_id'] as String,
        occurredAt: DateTime.parse(row['occurred_at'] as String).toUtc(),
        awardedAt: DateTime.parse(row['awarded_at'] as String).toUtc(),
      );
}
