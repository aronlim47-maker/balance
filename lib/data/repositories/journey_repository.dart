import '../../domain/models/local_date.dart';
import '../../domain/models/planning_data.dart';

/// Read-only evidence for Journey. Fetching never grants an achievement.
abstract interface class JourneyRepository {
  Future<List<ReflectionEntry>> fetchReflections({
    required LocalDate from,
    required LocalDate until,
  });
  Future<List<PlanningEvent>> fetchEvents({
    required DateTime from,
    required DateTime until,
  });
  Future<List<AchievementDefinition>> fetchAchievementDefinitions({
    required String ruleVersion,
  });

  /// Lifetime awards, not just awards earned in the displayed week.
  Future<List<AchievementAward>> fetchAchievements();
}
