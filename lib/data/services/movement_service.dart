import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/movement_models.dart';
import '../repositories/movement_repository.dart';
import 'authenticated_user.dart';

class MovementService implements MovementRepository {
  MovementService(this._client);

  final SupabaseClient _client;

  @override
  Future<MovementSettings> fetchSettings() async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('world_status_settings')
        .select(
          'movement_tracking_enabled,movement_target_days,target_recovery_minutes,target_social_minutes_week',
        )
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const MovementSettings();
    return _settings(row);
  }

  @override
  Future<MovementSettings> saveSettings(MovementSettings settings) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('world_status_settings')
        .upsert({
          'user_id': userId,
          'movement_tracking_enabled': settings.trackingEnabled,
          'movement_target_days': settings.targetDays,
          'target_recovery_minutes': settings.targetRecoveryMinutes,
          'target_social_minutes_week': settings.targetSocialMinutesWeek,
        }, onConflict: 'user_id')
        .select(
          'movement_tracking_enabled,movement_target_days,target_recovery_minutes,target_social_minutes_week',
        )
        .single();
    return _settings(row);
  }

  @override
  Future<ExerciseLog?> fetchLatestExerciseBefore(DateTime endExclusive) async {
    requireAuthenticatedUserId(_client);
    final row = await _client
        .from('exercise_logs')
        .select('id,task_id,occurred_at,duration_minutes,intensity')
        .lt('occurred_at', endExclusive.toUtc().toIso8601String())
        .order('occurred_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : _log(row);
  }

  @override
  Future<List<ExerciseLog>> fetchExerciseLogsForDay(DateTime day) async {
    requireAuthenticatedUserId(_client);
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    final rows = await _client
        .from('exercise_logs')
        .select('id,task_id,occurred_at,duration_minutes,intensity')
        .gte('occurred_at', start.toUtc().toIso8601String())
        .lt('occurred_at', end.toUtc().toIso8601String())
        .order('occurred_at', ascending: false);
    return rows.map(_log).toList(growable: false);
  }

  @override
  Future<ExerciseLog> createExerciseLog(ExerciseLog log) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('exercise_logs')
        .insert({
          'user_id': userId,
          'occurred_at': log.occurredAt.toUtc().toIso8601String(),
          'duration_minutes': log.durationMinutes,
          'intensity': log.intensity,
          'source': 'manual',
        })
        .select('id,task_id,occurred_at,duration_minutes,intensity')
        .single();
    return _log(row);
  }

  @override
  Future<void> deleteExerciseLog(String id) async {
    requireAuthenticatedUserId(_client);
    await _client.from('exercise_logs').delete().eq('id', id);
  }

  static MovementSettings _settings(Map<String, dynamic> row) =>
      MovementSettings(
        trackingEnabled: row['movement_tracking_enabled'] as bool? ?? false,
        targetDays: (row['movement_target_days'] as num?)?.toInt() ?? 3,
        targetRecoveryMinutes:
            (row['target_recovery_minutes'] as num?)?.toInt() ?? 30,
        targetSocialMinutesWeek:
            (row['target_social_minutes_week'] as num?)?.toInt() ?? 300,
      );

  static ExerciseLog _log(Map<String, dynamic> row) => ExerciseLog(
    id: row['id'] as String,
    taskId: row['task_id'] as String?,
    occurredAt: DateTime.parse(row['occurred_at'] as String),
    durationMinutes: (row['duration_minutes'] as num).toInt(),
    intensity: row['intensity'] as String?,
  );
}
