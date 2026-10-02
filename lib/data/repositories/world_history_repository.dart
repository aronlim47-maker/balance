import '../../domain/usecases/world_status_calculator.dart';

class WeeklyJourney {
  const WeeklyJourney({
    required this.weekStart,
    required this.dailyScores,
    required this.protectedRecoveryDays,
    this.recoveryRecordedDays = 0,
  });
  final DateTime weekStart;
  final List<int?> dailyScores;
  final int protectedRecoveryDays;
  final int recoveryRecordedDays;
}

abstract interface class WorldHistoryRepository {
  Future<WorldStatusResult?> loadDaySnapshot(DateTime day);

  /// Captures today's server-derived result only; never fabricates past days.
  Future<List<int?>> loadPreviousWeek(DateTime selectedDay);
  Future<WeeklyJourney> loadWeek(DateTime weekStart);
}
