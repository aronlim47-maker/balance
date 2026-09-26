import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../domain/models/plan_change.dart';
import '../../domain/models/plan_reservation.dart';
import '../mappers/plan_mapper.dart';
import '../repositories/plan_repository.dart';
import 'authenticated_user.dart';

class PlanService implements PlanRepository {
  PlanService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PlanChange>> fetchPlanChanges() async {
    requireAuthenticatedUserId(_client);
    final rows = await _client
        .from('plan_changes')
        .select()
        .order('created_at', ascending: false);
    return rows.map(PlanMapper.fromJson).toList(growable: false);
  }

  @override
  Future<List<PlanReservation>> fetchPlanReservations() async {
    requireAuthenticatedUserId(_client);
    final changes = await fetchPlanChanges();
    final confirmedIds = changes
        .where((change) => change.status.name == 'confirmed')
        .map((change) => change.id)
        .toSet();
    if (confirmedIds.isEmpty) return const [];
    final rows = await _client
        .from('plan_change_items')
        .select('plan_change_id,task_id,proposed_start,proposed_end');
    return rows
        .where((row) => confirmedIds.contains(row['plan_change_id']))
        .map(
          (row) => PlanReservation(
            taskId: row['task_id'] as String,
            startAt: DateTime.parse(row['proposed_start'] as String),
            endAt: DateTime.parse(row['proposed_end'] as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<int> calculateDayOverload(DateTime day) async {
    final userId = requireAuthenticatedUserId(_client);
    return _client.rpc<int>(
      'calculate_day_overload',
      params: {
        'p_user_id': userId,
        'p_day': DateFormat('yyyy-MM-dd').format(day),
      },
    );
  }

  @override
  Future<bool> hasWarCouncilMigration() async {
    requireAuthenticatedUserId(_client);
    try {
      final version = await _client.rpc<int>('war_council_schema_version');
      return version >= 2;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.code == '42883') return false;
      rethrow;
    }
  }

  @override
  Future<PlanChange> confirm({
    required List<PlanMove> moves,
    DateTime? recoveryStart,
    DateTime? recoveryEnd,
    Map<String, dynamic> consequences = const <String, dynamic>{},
  }) async {
    requireAuthenticatedUserId(_client);
    if (moves.isEmpty) {
      throw ArgumentError.value(
        moves,
        'moves',
        'At least one move is required.',
      );
    }
    if ((recoveryStart == null) != (recoveryEnd == null)) {
      throw ArgumentError(
        'Recovery start and recovery end must be supplied together.',
      );
    }

    final changeId = await _client.rpc<String>(
      'confirm_plan_change',
      params: {
        'p_moves': moves.map((move) => move.toJson()).toList(growable: false),
        'p_recovery_start': recoveryStart?.toUtc().toIso8601String(),
        'p_recovery_end': recoveryEnd?.toUtc().toIso8601String(),
        'p_consequences': consequences,
      },
    );
    final row = await _client
        .from('plan_changes')
        .select()
        .eq('id', changeId)
        .single();
    return PlanMapper.fromJson(row);
  }

  @override
  Future<void> undo(String changeId) async {
    requireAuthenticatedUserId(_client);
    await _client.rpc<void>(
      'undo_plan_change',
      params: {'p_change_id': changeId},
    );
  }
}
