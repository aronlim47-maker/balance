import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/local_date.dart';
import '../../domain/models/planning_data.dart';
import '../mappers/planning_data_mapper.dart';
import '../repositories/journey_repository.dart';
import '../repositories/world_status_repository.dart';
import 'authenticated_user.dart';

/// Owned, paginated reads only. Instantiate after the additive migration exists.
/// Errors propagate to the view model: unavailable data must not become zero.
class PlanningReadService implements WorldStatusRepository, JourneyRepository {
  PlanningReadService(this._client);

  final SupabaseClient _client;
  static const _pageSize = 100;
  static const _maxRows = 10000;

  void _checkOwner(String owner) {
    if (_client.auth.currentUser?.id != owner) {
      throw StateError('Account changed. Reload this view.');
    }
  }

  Future<List<T>> _read<T>(
    String table,
    T Function(Map<String, dynamic>) map, {
    PostgrestFilterBuilder<PostgrestList> Function(
      PostgrestFilterBuilder<PostgrestList>,
    )?
    filter,
    required String order,
    String? tieBreaker,
    bool catalogue = false,
  }) async {
    final owner = requireAuthenticatedUserId(_client);
    final result = <T>[];
    var offset = 0;
    while (true) {
      _checkOwner(owner);
      var query = _client.from(table).select();
      if (!catalogue) query = query.eq('user_id', owner);
      if (filter != null) query = filter(query);
      var ordered = query.order(order, ascending: true);
      if (tieBreaker != null) {
        ordered = ordered.order(tieBreaker, ascending: true);
      }
      final rows = await ordered.range(offset, offset + _pageSize - 1);
      _checkOwner(owner);
      if (rows.isEmpty) return List<T>.unmodifiable(result);
      if (offset + rows.length > _maxRows) {
        throw StateError('Too much history. Choose a shorter date range.');
      }
      // A short page may reflect a server-side row cap. Continue until empty.
      result.addAll(rows.map(map));
      offset += rows.length;
    }
  }

  void _dateRange(LocalDate from, LocalDate until) {
    if (from.compareTo(until) >= 0) {
      throw ArgumentError('The end date must be after the start date.');
    }
  }

  void _instantRange(DateTime from, DateTime until) {
    if (!from.isUtc || !until.isUtc || !from.isBefore(until)) {
      throw ArgumentError(
        'Provide an increasing range of explicit UTC instants.',
      );
    }
  }

  @override
  Future<WorldStatusSettings?> fetchSettings() async {
    final rows = await _read(
      'world_status_settings',
      PlanningDataMapper.worldStatusSettings,
      order: 'user_id',
    );
    return rows.singleOrNull;
  }

  @override
  Future<List<WorldStatusSnapshot>> fetchSnapshots({
    required LocalDate from,
    required LocalDate until,
    required String formulaVersion,
  }) {
    _dateRange(from, until);
    if (formulaVersion.trim().isEmpty) {
      throw ArgumentError('Formula version required.');
    }
    return _read(
      'world_status_snapshots',
      PlanningDataMapper.worldStatusSnapshot,
      order: 'local_date',
      filter: (q) => q
          .gte('local_date', from.toString())
          .lt('local_date', until.toString())
          .eq('formula_version', formulaVersion),
    );
  }

  @override
  Future<List<ExerciseLog>> fetchExerciseLogs({
    required DateTime from,
    required DateTime until,
  }) {
    _instantRange(from, until);
    return _read(
      'exercise_logs',
      PlanningDataMapper.exerciseLog,
      order: 'occurred_at',
      tieBreaker: 'id',
      filter: (q) => q
          .gte('occurred_at', from.toIso8601String())
          .lt('occurred_at', until.toIso8601String()),
    );
  }

  @override
  Future<List<SocialEvent>> fetchSocialEvents({
    required DateTime from,
    required DateTime until,
  }) {
    _instantRange(from, until);
    return _read(
      'social_events',
      PlanningDataMapper.socialEvent,
      order: 'start_at',
      tieBreaker: 'id',
      filter: (q) => q
          .lt('start_at', until.toIso8601String())
          .gt('end_at', from.toIso8601String()),
    );
  }

  @override
  Future<SocialWeekResponse?> fetchSocialWeekResponse(
    LocalDate weekStart,
  ) async {
    if (weekStart.value.weekday != DateTime.monday) {
      throw ArgumentError(
        'Week start must be a Monday in the profile time zone.',
      );
    }
    final rows = await _read(
      'social_week_responses',
      PlanningDataMapper.socialWeekResponse,
      order: 'week_start',
      filter: (q) => q.eq('week_start', weekStart.toString()),
    );
    return rows.singleOrNull;
  }

  @override
  Future<List<ReflectionEntry>> fetchReflections({
    required LocalDate from,
    required LocalDate until,
  }) {
    _dateRange(from, until);
    return _read(
      'reflections',
      PlanningDataMapper.reflectionEntry,
      order: 'local_date',
      tieBreaker: 'id',
      filter: (q) => q
          .gte('local_date', from.toString())
          .lt('local_date', until.toString()),
    );
  }

  @override
  Future<List<PlanningEvent>> fetchEvents({
    required DateTime from,
    required DateTime until,
  }) {
    _instantRange(from, until);
    return _read(
      'planning_events',
      PlanningDataMapper.planningEvent,
      order: 'occurred_at',
      tieBreaker: 'id',
      filter: (q) => q
          .gte('occurred_at', from.toIso8601String())
          .lt('occurred_at', until.toIso8601String()),
    );
  }

  @override
  Future<List<AchievementDefinition>> fetchAchievementDefinitions({
    required String ruleVersion,
  }) {
    if (ruleVersion.trim().isEmpty) {
      throw ArgumentError('Rule version required.');
    }
    return _read(
      'achievement_definitions',
      PlanningDataMapper.achievementDefinition,
      order: 'achievement_key',
      catalogue: true,
      filter: (q) => q.eq('rule_version', ruleVersion),
    );
  }

  @override
  Future<List<AchievementAward>> fetchAchievements() => _read(
    'user_achievements',
    PlanningDataMapper.achievementAward,
    order: 'achievement_key',
  );
}
