import '../../domain/models/local_date.dart';
import '../../domain/models/planning_data.dart';

/// Implementations derive the owner from the authenticated session, not a UI ID.
/// All date ranges are [from, until); use the profile time zone at the boundary.
abstract interface class WorldStatusRepository {
  Future<WorldStatusSettings?> fetchSettings();
  Future<List<WorldStatusSnapshot>> fetchSnapshots({
    required LocalDate from,
    required LocalDate until,
    required String formulaVersion,
  });
  Future<List<ExerciseLog>> fetchExerciseLogs({
    required DateTime from,
    required DateTime until,
  });
  Future<List<SocialEvent>> fetchSocialEvents({
    required DateTime from,
    required DateTime until,
  });
  Future<SocialWeekResponse?> fetchSocialWeekResponse(LocalDate weekStart);
  // No snapshot insert/update API. Trusted recalculation is a separate handoff.
}
