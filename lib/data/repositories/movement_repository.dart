import '../../domain/models/movement_models.dart';

abstract interface class MovementRepository {
  Future<MovementSettings> fetchSettings();
  Future<MovementSettings> saveSettings(MovementSettings settings);
  Future<ExerciseLog?> fetchLatestExerciseBefore(DateTime endExclusive);
  Future<List<ExerciseLog>> fetchExerciseLogsForDay(DateTime day);
  Future<ExerciseLog> createExerciseLog(ExerciseLog log);
  Future<void> deleteExerciseLog(String id);
}
