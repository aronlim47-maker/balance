class WeeklyJourney {
  const WeeklyJourney({required this.weekStart, required this.dailyScores,
    required this.protectedRecoveryDays});
  final DateTime weekStart;
  final List<int?> dailyScores;
  final int protectedRecoveryDays;
}

abstract interface class WorldHistoryRepository {
  /// Captures today's server-derived result only; never fabricates past days.
  Future<List<int?>> loadPreviousWeek(DateTime selectedDay);
  Future<WeeklyJourney> loadWeek(DateTime weekStart);
}
