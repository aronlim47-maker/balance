import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/check_in.dart';
import '../mappers/check_in_mapper.dart';
import '../repositories/check_in_repository.dart';
import 'authenticated_user.dart';

class CheckInService implements CheckInRepository {
  CheckInService(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CheckIn>> fetchCheckIns() async {
    final userId = requireAuthenticatedUserId(_client);
    final rows = await _client
        .from('check_ins')
        .select()
        .order('check_in_date', ascending: false);
    ensureAuthenticatedUserUnchanged(_client, userId);
    return rows.map(CheckInMapper.fromJson).toList(growable: false);
  }

  @override
  Future<CheckIn?> fetchCheckIn(DateTime date) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('check_ins')
        .select()
        .eq('check_in_date', CheckInMapper.dateValue(date))
        .maybeSingle();
    ensureAuthenticatedUserUnchanged(_client, userId);
    return row == null ? null : CheckInMapper.fromJson(row);
  }

  @override
  Future<CheckIn> saveCheckIn(CheckIn checkIn) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('check_ins')
        .upsert(
          CheckInMapper.toUpsert(checkIn, userId),
          onConflict: 'user_id,check_in_date',
        )
        .select()
        .single();
    ensureAuthenticatedUserUnchanged(_client, userId);
    return CheckInMapper.fromJson(row);
  }

  @override
  Future<void> deleteCheckIn(DateTime date) async {
    final userId = requireAuthenticatedUserId(_client);
    await _client
        .from('check_ins')
        .delete()
        .eq('check_in_date', CheckInMapper.dateValue(date));
    ensureAuthenticatedUserUnchanged(_client, userId);
  }
}
