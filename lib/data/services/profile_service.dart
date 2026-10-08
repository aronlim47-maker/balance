import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/app_profile.dart';
import '../repositories/profile_repository.dart';
import 'authenticated_user.dart';

class ProfileService implements ProfileRepository {
  ProfileService(this._client);

  final SupabaseClient _client;

  @override
  Future<AppProfile> fetchProfile() async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('profiles')
        .select('display_name,time_zone')
        .eq('id', userId)
        .single();
    ensureAuthenticatedUserUnchanged(_client, userId);
    return _fromJson(row);
  }

  @override
  Future<AppProfile> updateTimeZone(String timeZone) async {
    final userId = requireAuthenticatedUserId(_client);
    final row = await _client
        .from('profiles')
        .update({'time_zone': timeZone.trim()})
        .eq('id', userId)
        .select('display_name,time_zone')
        .single();
    ensureAuthenticatedUserUnchanged(_client, userId);
    return _fromJson(row);
  }

  static AppProfile _fromJson(Map<String, dynamic> row) => AppProfile(
    displayName: row['display_name'] as String? ?? '',
    timeZone: row['time_zone'] as String? ?? 'UTC',
  );
}
