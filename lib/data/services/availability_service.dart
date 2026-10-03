import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/availability_block.dart';
import '../mappers/availability_mapper.dart';
import '../repositories/availability_repository.dart';
import 'authenticated_user.dart';
import 'owned_rows.dart';

class AvailabilityService implements AvailabilityRepository {
  AvailabilityService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AvailabilityBlock>> fetchAvailability() async {
    final rows = await readOwnedRows(
      _client,
      (owner) => _client
          .from('availability_blocks')
          .select()
          .eq('user_id', owner)
          .order('start_at')
          .order('id'),
    );
    return rows.map(AvailabilityMapper.fromJson).toList(growable: false);
  }

  @override
  Future<AvailabilityBlock> createAvailability(AvailabilityBlock block) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('availability_blocks')
        .insert(AvailabilityMapper.toInsert(block, userId))
        .select()
        .single();
    return AvailabilityMapper.fromJson(row);
  }

  @override
  Future<AvailabilityBlock> updateAvailability(AvailabilityBlock block) async {
    requireAuthenticatedUserId(_client);
    final row = await _client
        .from('availability_blocks')
        .update(AvailabilityMapper.toUpdate(block))
        .eq('id', block.id)
        .select()
        .single();
    return AvailabilityMapper.fromJson(row);
  }

  @override
  Future<void> deleteAvailability(String blockId) async {
    requireAuthenticatedUserId(_client);
    final deleted = await _client
        .from('availability_blocks')
        .delete()
        .eq('id', blockId)
        .select('id')
        .maybeSingle();
    if (deleted == null) throw StateError('Deletion not confirmed');
  }
}
