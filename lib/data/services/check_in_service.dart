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
    requireAuthenticatedUserId(_client);
    final rows = await _client
        .from('check_ins')
        .select()
        .order('check_in_date', ascending: false);
    return rows.map(CheckInMapper.fromJson).toList(growable: false);
  }

  @override
  Future<CheckIn?> fetchCheckIn(DateTime date) async {
    requireAuthenticatedUserId(_client);
    final row = await _client
        .from('check_ins')
        .select()
        .eq('check_in_date', CheckInMapper.dateValue(date))
        .maybeSingle();
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
    return CheckInMapper.fromJson(row);
  }

  @override
  Future<void> deleteCheckIn(DateTime date) async {
    requireAuthenticatedUserId(_client);
    await _client
        .from('check_ins')
        .delete()
        .eq('check_in_date', CheckInMapper.dateValue(date));
  }
}
