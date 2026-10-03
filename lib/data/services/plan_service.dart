import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../domain/models/plan_change.dart';
import '../../domain/enums/plan_status.dart';
import '../../domain/enums/validation_status.dart';
import '../../domain/models/plan_reservation.dart';
import '../mappers/plan_mapper.dart';
import '../repositories/plan_repository.dart';
import 'authenticated_user.dart';
import 'owned_rows.dart';

class PlanService implements PlanRepository {
  PlanService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PlanChange>> fetchPlanChanges() async {
    final rows = await readOwnedRows(
      _client,
      (owner) => _client
          .from('plan_changes')
          .select()
          .eq('user_id', owner)
          .order('created_at', ascending: false)
          .order('id'),
    );
    return rows.map(PlanMapper.fromJson).toList(growable: false);
  }

  @override
  Future<List<PlanReservation>> fetchPlanReservations() async {
    final rows = await readOwnedRows(
      _client,
      (owner) => _client
          .from('plan_change_items')
          .select(
            'plan_change_id,task_id,proposed_start,proposed_end,tasks!inner(status),plan_changes!inner(status)',
          )
          .eq('tasks.status', 'planned')
          .eq('plan_changes.status', 'confirmed')
          .eq('plan_changes.user_id', owner)
          .order('id'),
    );
    return rows
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
    // The RPC returns an ID only after the transaction has committed.
    // Detail loading belongs to the result page and must not turn success
    // into a failed confirmation if a subsequent request loses connectivity.
    return PlanChange(
      id: changeId,
      status: PlanStatus.confirmed,
      validationStatus: ValidationStatus.feasible,
      consequences: consequences,
    );
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
