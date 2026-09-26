import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/recovery_slot.dart';
import '../mappers/recovery_mapper.dart';
import '../repositories/recovery_repository.dart';
import 'authenticated_user.dart';

class RecoveryService implements RecoveryRepository {
  RecoveryService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RecoverySlot>> fetchRecoverySlots() async {
    requireAuthenticatedUserId(_client);
    final rows = await _client
        .from('recovery_slots')
        .select()
        .order('start_at');
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
    return RecoveryMapper.fromJson(row);
  }

  @override
  Future<RecoverySlot> updateRecoverySlot(RecoverySlot slot) async {
    requireAuthenticatedUserId(_client);
    final row = await _client
        .from('recovery_slots')
        .update(RecoveryMapper.toUpdate(slot))
        .eq('id', slot.id)
        .select()
        .single();
    return RecoveryMapper.fromJson(row);
  }

  @override
  Future<void> deleteRecoverySlot(String slotId) async {
    requireAuthenticatedUserId(_client);
    await _client.from('recovery_slots').delete().eq('id', slotId);
  }
}
