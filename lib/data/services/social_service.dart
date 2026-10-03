import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/social_event_record.dart';
import '../../domain/usecases/world_status_calculator.dart';
import '../repositories/social_repository.dart';
import 'authenticated_user.dart';
import 'owned_rows.dart';
import 'retry_safe_write.dart';

class SocialService implements SocialRepository {
  SocialService(this._client);

  final SupabaseClient _client;
  final _writes = RetrySafeWrite();

  @override
  Future<List<SocialEventRecord>> fetchEventsForWeek(DateTime day) async {
    final userId = requireAuthenticatedUserId(_client);
    final localDay = DateTime(day.year, day.month, day.day);
    final start = localDay.subtract(Duration(days: localDay.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final rows = await readOwnedRows(
      _client,
      (_) => _client
          .from('social_events')
          .select('id,start_at,end_at,pressure_level,task_id')
          .eq('user_id', userId)
          .gt('end_at', start.toUtc().toIso8601String())
          .lt('start_at', end.toUtc().toIso8601String())
          .order('start_at')
          .order('id'),
    );
    return rows
        .map((row) {
          final starts = DateTime.parse(row['start_at'] as String);
          final ends = DateTime.parse(row['end_at'] as String);
          final pressure = switch (row['pressure_level'] as String) {
            'low' => SocialPressure.low,
            'moderate' => SocialPressure.moderate,
            'high' => SocialPressure.high,
            _ => SocialPressure.neutral,
          };
          return SocialEventRecord(
            id: row['id'] as String,
            taskId: row['task_id'] as String?,
            startAt: starts,
            endAt: ends,
            pressure: pressure,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<bool> fetchNoCommitmentsForWeek(DateTime day) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('social_week_responses')
        .select('no_commitments')
        .eq('user_id', userId)
        .eq('week_start', _weekStart(day))
        .maybeSingle();
    return row?['no_commitments'] as bool? ?? false;
  }

  @override
  Future<void> saveNoCommitmentsForWeek(
    DateTime day,
    bool noCommitments,
  ) async {
    final userId = requireAuthenticatedUserId(_client);
    await _client.from('social_week_responses').upsert({
      'user_id': userId,
      'week_start': _weekStart(day),
      'no_commitments': noCommitments,
    }, onConflict: 'user_id,week_start');
  }

  @override
  Future<SocialEventRecord> createEvent(SocialEventRecord event) async {
    requireAuthenticatedUserId(_client);
    final payload = {
      'p_start_at': event.startAt.toUtc().toIso8601String(),
      'p_end_at': event.endAt.toUtc().toIso8601String(),
      'p_pressure_level': event.pressure.name,
      'p_task_id': event.taskId,
      'p_week_start': _weekStart(event.startAt.toLocal()),
    };
    final row = await _writes.run(
      _client,
      'social_event',
      payload,
      (requestId, _) => _client.rpc<Map<String, dynamic>>(
        'create_social_event_once',
        params: {...payload, 'p_request_id': requestId},
      ),
    );
    return SocialEventRecord(
      id: row['id'] as String,
      taskId: row['task_id'] as String?,
      startAt: DateTime.parse(row['start_at'] as String),
      endAt: DateTime.parse(row['end_at'] as String),
      pressure: SocialPressure.values.byName(row['pressure_level'] as String),
    );
  }

  @override
  Future<void> deleteEvent(String id) async {
    final userId = requireAuthenticatedUserId(_client);
    final deleted = await _client
        .from('social_events')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select('id')
        .maybeSingle();
    if (deleted == null) throw StateError('Deletion not confirmed');
  }

  static String _weekStart(DateTime day) {
    final localDay = DateTime(day.year, day.month, day.day);
    final start = localDay.subtract(Duration(days: localDay.weekday - 1));
    final year = start.year.toString().padLeft(4, '0');
    final month = start.month.toString().padLeft(2, '0');
    final date = start.day.toString().padLeft(2, '0');
    return '$year-$month-$date';
  }
}
