import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/world_history_repository.dart';
import 'authenticated_user.dart';
import '../../domain/usecases/world_status_calculator.dart';

class WorldHistoryService implements WorldHistoryRepository {
  WorldHistoryService(this.client);
  final SupabaseClient client;
  @override
  Future<WorldStatusResult?> loadDaySnapshot(DateTime day) async {
    final user = requireAuthenticatedUserId(client);
    final row = await client
        .from('world_status_snapshots')
        .select()
        .eq('user_id', user)
        .eq('formula_version', WorldStatusCalculator.formulaVersion)
        .eq('local_date', DateFormat('yyyy-MM-dd').format(day))
        .maybeSingle();
    return row == null ? null : WorldStatusResult.fromSnapshot(row);
  }

  @override
  Future<List<int?>> loadPreviousWeek(DateTime selectedDay) async {
    final user = requireAuthenticatedUserId(client);
    await client.rpc('capture_world_status');
    final dates = List.generate(
      7,
      (i) => DateFormat('yyyy-MM-dd').format(
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day - 7 + i),
      ),
    );
    final rows = await client
        .from('world_status_snapshots')
        .select('local_date,total_score')
        .eq('user_id', user)
        .eq('formula_version', 'world_status_v1')
        .gte('local_date', dates.first)
        .lte('local_date', dates.last);
    final scores = {
      for (final row in rows)
        row['local_date'] as String: (row['total_score'] as num?)?.toInt(),
    };
    return dates.map((date) => scores[date]).toList();
  }

  @override
  Future<WeeklyJourney> loadWeek(DateTime weekStart) async {
    final user = requireAuthenticatedUserId(client);
    final monday = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - weekStart.weekday + 1,
    );
    final dates = List.generate(
      7,
      (i) =>
          DateFormat('yyyy-MM-dd')
              .format(DateTime(monday.year, monday.month, monday.day + i)),
    );
    final rows = await client
        .from('world_status_snapshots')
        .select('local_date,total_score,had_protected_recovery')
        .eq('user_id', user)
        .eq('formula_version', 'world_status_v1')
        .gte('local_date', dates.first)
        .lte('local_date', dates.last);
    final scores = {
      for (final row in rows)
        row['local_date'] as String: (row['total_score'] as num?)?.toInt(),
    };
    final protectedDays = rows
        .where((row) => row['had_protected_recovery'] == true)
        .length;
    final recordedDays = rows
        .where((row) => row['had_protected_recovery'] != null)
        .length;
    return WeeklyJourney(
      weekStart: monday,
      dailyScores: dates.map((date) => scores[date]).toList(),
      protectedRecoveryDays: protectedDays,
      recoveryRecordedDays: recordedDays,
    );
  }
}
