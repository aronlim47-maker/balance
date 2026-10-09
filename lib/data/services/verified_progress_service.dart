import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_user.dart';
import 'retry_safe_write.dart';
import 'owned_rows.dart';
import '../../domain/models/reflection_record.dart';

class VerifiedProgressService {
  VerifiedProgressService(this.client);
  final SupabaseClient client;
  final _writes = RetrySafeWrite();

  Future<List<ReflectionRecord>> fetchReflections() async {
    final rows = await readOwnedRows(
      client,
      (owner) => client
          .from('reflections')
          .select('id,body,created_at')
          .eq('user_id', owner)
          .order('created_at', ascending: false)
          .order('id'),
    );
    return rows
        .map(
          (row) => ReflectionRecord(
            body: row['body'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> saveReflection(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) throw ArgumentError('Write a reflection first.');
    await _writes.insert(client, 'reflections', {'body': trimmed});
  }

  Future<void> acknowledgeOverload(String taskId) async {
    requireAuthenticatedUserId(client);
    await client.rpc('acknowledge_overload', params: {'p_task': taskId});
  }
}
