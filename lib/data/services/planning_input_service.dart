import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/local_date.dart';
import '../../domain/models/planning_data.dart';
import '../mappers/planning_data_mapper.dart';
import '../repositories/planning_input_repository.dart';
import 'authenticated_user.dart';

/// Raw inputs for the draft 001 schema. Does not calculate or award progress.
/// RLS and composite foreign keys remain the authority for linked ownership.
class PlanningInputService implements PlanningInputRepository {
  PlanningInputService(this._client);
  final SupabaseClient _client;

  void _checkOwner(String owner) {
    if (_client.auth.currentUser?.id != owner) {
      throw StateError('Account changed. Reload before retrying.');
    }
  }

  String _uuid(String value) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw ArgumentError('A UUID is required.');
    }
    return value.toLowerCase();
  }

  String _instant(DateTime value) {
    if (!value.isUtc) {
      throw ArgumentError('An explicit UTC instant is required.');
    }
    return value.toIso8601String();
  }

  /// Insert first: concurrent identical retries converge on the unique key.
  /// Other unique violations (e.g. a linked task) and all other errors propagate.
  Future<Map<String, dynamic>> _insert(
    String table,
    Map<String, dynamic> data, {
    Set<String> instants = const {},
  }) async {
    final owner = requireAuthenticatedUserId(_client);
    final payload = {...data, 'user_id': owner};
    try {
      final row = await _client.from(table).insert(payload).select().single();
      _checkOwner(owner);
      return row;
    } on PostgrestException catch (error) {
      _checkOwner(owner);
      if (error.code != '23505') {
        rethrow;
      }
      final row = await _client
          .from(table)
          .select()
          .eq('user_id', owner)
          .eq('request_id', data['request_id'] as String)
          .maybeSingle();
      _checkOwner(owner);
      if (row == null) {
        rethrow;
      }
      for (final entry in payload.entries) {
        final actual = row[entry.key];
        final matches = instants.contains(entry.key)
            ? actual is String &&
                  DateTime.parse(actual)
                      .isAtSameMomentAs(DateTime.parse(entry.value as String))
            : actual == entry.value;
        if (!matches) {
          throw StateError('Request ID already used with different input.');
        }
      }
      return row;
    }
  }

  Future<void> _updateOne(
    String table,
    String key,
    String value,
    Map<String, dynamic> data,
  ) async {
    final owner = requireAuthenticatedUserId(_client);
    final rows = await _client
        .from(table)
        .update(data)
        .eq('user_id', owner)
        .eq(key, value)
        .select(key);
    _checkOwner(owner);
    if (rows.length != 1) {
      throw StateError('Owned record not found. Reload before saving.');
    }
  }

  @override
  Future<void> setTaskCategory(String taskId, LoadCategory category) =>
      _updateOne('tasks', 'id', _uuid(taskId), {
        'load_category': category.name,
      });

  /// Patch an existing daily review; never invent legacy 1–5 ratings.
  @override
  Future<void> saveReviewEnergy({
    required LocalDate date,
    required EnergyLevel? mental,
    required EnergyLevel? physical,
  }) => _updateOne('check_ins', 'check_in_date', date.toString(), {
    'mental_energy_level': mental?.name,
    'physical_energy_level': physical?.name,
  });

  @override
  Future<ExerciseLog> confirmExercise({
    required String requestId,
    required DateTime occurredAt,
    required int durationMinutes,
    String? taskId,
    String? intensity,
  }) async {
    if (durationMinutes <= 0) {
      throw ArgumentError('Duration must be positive.');
    }
    return PlanningDataMapper.exerciseLog(
      await _insert(
        'exercise_logs',
        {
          'request_id': _uuid(requestId),
          'task_id': taskId == null ? null : _uuid(taskId),
          'occurred_at': _instant(occurredAt),
          'duration_minutes': durationMinutes,
          'intensity': intensity,
          'source': 'manual',
        },
        instants: {'occurred_at'},
      ),
    );
  }

  @override
  Future<SocialEvent> confirmSocialEvent({
    required String requestId,
    required DateTime startAt,
    required DateTime endAt,
    required EnergyLevel pressureLevel,
    required bool? hasConflict,
    String? taskId,
  }) async {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError('End must be after start.');
    }
    return PlanningDataMapper.socialEvent(
      await _insert(
        'social_events',
        {
          'request_id': _uuid(requestId),
          'task_id': taskId == null ? null : _uuid(taskId),
          'start_at': _instant(startAt),
          'end_at': _instant(endAt),
          'pressure_level': pressureLevel.name,
          'has_conflict': hasConflict,
        },
        instants: {'start_at', 'end_at'},
      ),
    );
  }

  @override
  Future<void> setSocialWeekResponse({
    required LocalDate weekStart,
    required bool noSocialCommitments,
  }) async {
    if (weekStart.value.weekday != DateTime.monday) {
      throw ArgumentError(
        'Week start must be Monday in the profile time zone.',
      );
    }
    final owner = requireAuthenticatedUserId(_client);
    await _client.from('social_week_responses').upsert({
      'user_id': owner,
      'week_start': weekStart.toString(),
      'no_social_commitments': noSocialCommitments,
    }, onConflict: 'user_id,week_start');
    _checkOwner(owner);
  }

  @override
  Future<ReflectionEntry> saveReflection({
    required String requestId,
    required LocalDate date,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      throw ArgumentError('Reflection cannot be empty.');
    }
    return PlanningDataMapper.reflectionEntry(
      await _insert('reflections', {
        'request_id': _uuid(requestId),
        'local_date': date.toString(),
        'content': content,
      }),
    );
  }

  @override
  Future<void> acknowledgeOverload({
    required String requestId,
    required String taskId,
    required LocalDate localDate,
  }) async {
    await _insert('overload_reviews', {
      'request_id': _uuid(requestId),
      'task_id': _uuid(taskId),
      'local_date': localDate.toString(),
    });
  }
}
