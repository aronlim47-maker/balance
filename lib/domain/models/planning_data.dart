import 'local_date.dart';

enum LoadCategory { study, errand, social, exercise, other }

enum EnergyLevel { low, moderate, high, neutral }

enum WorldStatusTrend { rising, stable, easing, notEnoughHistory }

class WorldStatusSettings {
  const WorldStatusSettings({
    required this.userId,
    required this.movementTrackingEnabled,
    required this.movementTargetDays,
    required this.targetRecoveryMinutes,
    required this.targetSocialMinutesWeek,
    required this.formulaVersion,
  });
  final String userId;
  final bool movementTrackingEnabled;
  final int movementTargetDays;
  final int targetRecoveryMinutes;
  final int targetSocialMinutesWeek;
  final String formulaVersion;
}

class ExerciseLog {
  const ExerciseLog({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.occurredAt,
    required this.durationMinutes,
    required this.intensity,
    required this.source,
    required this.requestId,
  });
  final String id;
  final String userId;
  final String? taskId;
  final DateTime occurredAt;
  final int durationMinutes;
  final String? intensity;
  final String source;
  final String requestId;
}

class SocialEvent {
  const SocialEvent({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.startAt,
    required this.endAt,
    required this.pressureLevel,
    required this.hasConflict,
    required this.requestId,
  });
  final String id;
  final String userId;
  final String? taskId;
  final DateTime startAt;
  final DateTime endAt;
  final EnergyLevel pressureLevel;
  final bool? hasConflict;
  final String requestId;
}

class SocialWeekResponse {
  const SocialWeekResponse({
    required this.userId,
    required this.weekStart,
    required this.noSocialCommitments,
  });
  final String userId;
  final LocalDate weekStart;
  final bool noSocialCommitments;
}

class ReflectionEntry {
  const ReflectionEntry({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.content,
    required this.requestId,
    required this.createdAt,
  });
  final String id;
  final String userId;
  final LocalDate? localDate;
  final String content;
  final String requestId;
  final DateTime createdAt;
}

class WorldStatusSnapshot {
  const WorldStatusSnapshot({
    required this.userId,
    required this.localDate,
    required this.mentalScore,
    required this.timeScore,
    required this.physicalScore,
    required this.socialScore,
    required this.errandsScore,
    required this.totalScore,
    required this.knownDimensions,
    required this.coverage,
    required this.trend,
    required this.formulaVersion,
    required this.computedAt,
  });
  final String userId;
  final LocalDate localDate;
  final double? mentalScore;
  final double? timeScore;
  final double? physicalScore;
  final double? socialScore;
  final double? errandsScore;
  final int? totalScore;
  final List<String> knownDimensions;
  final double coverage;
  final WorldStatusTrend trend;
  final String formulaVersion;
  final DateTime computedAt;
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.achievementKey,
    required this.practicalName,
    required this.rpgName,
    required this.unlockCondition,
    required this.ruleVersion,
  });
  final String achievementKey;
  final String practicalName;
  final String rpgName;
  final String unlockCondition;
  final String ruleVersion;
}

class PlanningEvent {
  const PlanningEvent({
    required this.id,
    required this.userId,
    required this.eventKey,
    required this.eventType,
    required this.occurredAt,
    required this.evidence,
  });
  final String id;
  final String userId;
  final String eventKey;
  final String eventType;
  final DateTime occurredAt;
  final Map<String, dynamic> evidence;
}

class AchievementAward {
  const AchievementAward({
    required this.userId,
    required this.achievementKey,
    required this.ruleVersion,
    required this.sourceEventId,
    required this.occurredAt,
    required this.awardedAt,
  });
  final String userId;
  final String achievementKey;
  final String ruleVersion;
  final String sourceEventId;
  final DateTime occurredAt;
  final DateTime awardedAt;
}
