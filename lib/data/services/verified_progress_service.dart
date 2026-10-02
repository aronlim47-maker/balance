import 'package:supabase_flutter/supabase_flutter.dart';
import 'authenticated_user.dart';

class VerifiedProgressService {
  VerifiedProgressService(this.client);
  final SupabaseClient client;

  Future<void> saveReflection(String body) async {
    final user = requireAuthenticatedUserId(client);
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw ArgumentError('Write a reflection first.');
    await client.from('reflections').insert({'user_id': user, 'body': trimmed});
  }

  Future<void> acknowledgeOverload(String taskId) async {
    requireAuthenticatedUserId(client);
    await client.rpc('acknowledge_overload', params: {'p_task': taskId});
  }
}
