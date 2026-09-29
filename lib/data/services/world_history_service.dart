import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/world_history_repository.dart';
import 'authenticated_user.dart';

class WorldHistoryService implements WorldHistoryRepository {
  WorldHistoryService(this.client);
  final SupabaseClient client;
  @override
  Future<List<int?>> loadPreviousWeek(DateTime selectedDay) async {
    final user = requireAuthenticatedUserId(client);
    await client.rpc('capture_world_status');
    final dates = List.generate(7, (i) => DateFormat('yyyy-MM-dd').format(
      DateTime(selectedDay.year, selectedDay.month, selectedDay.day - 7 + i)));
    final rows = await client.from('world_status_snapshots')
      .select('local_date,total_score').eq('user_id', user)
      .eq('formula_version', 'world_status_v1')
      .gte('local_date', dates.first).lte('local_date', dates.last);
    final scores = {for (final row in rows)
      row['local_date'] as String: (row['total_score'] as num?)?.toInt()};
    return dates.map((date) => scores[date]).toList();
  }

  @override
  Future<WeeklyJourney> loadWeek(DateTime weekStart) async {
    final user = requireAuthenticatedUserId(client);
    final monday = DateTime(weekStart.year, weekStart.month,
      weekStart.day - weekStart.weekday + 1);
    final end = DateTime(monday.year, monday.month, monday.day + 7);
    final dates = List.generate(7, (i) => DateFormat('yyyy-MM-dd').format(
      DateTime(monday.year, monday.month, monday.day + i)));
    final rows = await client.from('world_status_snapshots')
      .select('local_date,total_score').eq('user_id', user)
      .eq('formula_version', 'world_status_v1')
      .gte('local_date', dates.first).lte('local_date', dates.last);
    final recoveryRows = await client.from('recovery_slots')
      .select('start_at,end_at').eq('user_id',user).eq('is_protected',true)
      .lt('start_at',end.toUtc().toIso8601String())
      .gt('end_at',monday.toUtc().toIso8601String());
    final scores = {for (final row in rows)
      row['local_date'] as String: (row['total_score'] as num?)?.toInt()};
    var protectedDays = 0;
    for (var i = 0; i < 7; i++) {
      final dayStart = DateTime(monday.year, monday.month, monday.day + i);
      final dayEnd = DateTime(monday.year, monday.month, monday.day + i + 1);
      if (recoveryRows.any((row) => DateTime.parse(row['start_at'] as String)
          .isBefore(dayEnd) && DateTime.parse(row['end_at'] as String)
          .isAfter(dayStart))) {
        protectedDays++;
      }
    }
    return WeeklyJourney(weekStart: monday,
      dailyScores: dates.map((date) => scores[date]).toList(),
      protectedRecoveryDays: protectedDays);
  }
}
