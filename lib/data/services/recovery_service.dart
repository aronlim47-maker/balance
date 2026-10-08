import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/recovery_slot.dart';
import '../mappers/recovery_mapper.dart';
import '../repositories/recovery_repository.dart';
import 'authenticated_user.dart';
import 'owned_rows.dart';

class RecoveryService implements RecoveryRepository {
  RecoveryService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RecoverySlot>> fetchRecoverySlots() async {
    final rows = await readOwnedRows(
      _client,
      (owner) => _client
          .from('recovery_slots')
          .select()
          .eq('user_id', owner)
          .order('start_at')
          .order('id'),
    );
    return rows.map(RecoveryMapper.fromJson).toList(growable: false);
  }

  @override
  Future<RecoverySlot> createRecoverySlot(RecoverySlot slot) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('recovery_slots')
        .insert(RecoveryMapper.toInsert(slot, userId))
        .select()
        .single();
    ensureAuthenticatedUserUnchanged(_client, userId);
    return RecoveryMapper.fromJson(row);
  }

  @override
  Future<RecoverySlot> updateRecoverySlot(RecoverySlot slot) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('recovery_slots')
        .update(RecoveryMapper.toUpdate(slot))
        .eq('id', slot.id)
        .select()
        .single();
    ensureAuthenticatedUserUnchanged(_client, userId);
    return RecoveryMapper.fromJson(row);
  }

  @override
  Future<void> deleteRecoverySlot(String slotId) async {
    final userId = requireAuthenticatedUserId(_client);
    final deleted = await _client
        .from('recovery_slots')
        .delete()
        .eq('id', slotId)
        .select('id')
        .maybeSingle();
    ensureAuthenticatedUserUnchanged(_client, userId);
    if (deleted == null) throw StateError('Deletion not confirmed');
  }
}
