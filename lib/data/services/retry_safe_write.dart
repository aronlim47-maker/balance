import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'authenticated_user.dart';

/// Keeps the same request ID after an uncertain response, within this session.
/// Successful writes release the key so intentional identical entries are allowed.
/// An app restart needs a persisted outbox; this helper does not claim offline sync.
class RetrySafeWrite {
  final Map<String, String> _pending = {};

  Future<Map<String, dynamic>> run(
    SupabaseClient client,
    String operation,
    Map<String, dynamic> payload,
    Future<Map<String, dynamic>> Function(String requestId, String owner) write,
  ) async {
    final owner = requireAuthenticatedUserId(client);
    final key = jsonEncode([owner, operation, payload]);
    final id = _pending.putIfAbsent(key, () => const Uuid().v4());
    final row = await write(id, owner);
    if (requireAuthenticatedUserId(client) != owner) {
      throw StateError('Account changed. Reload before retrying.');
    }
    _pending.remove(key);
    return row;
  }

  Future<Map<String, dynamic>> insert(
    SupabaseClient client,
    String table,
    Map<String, dynamic> payload,
  ) => run(client, table, payload, (requestId, owner) async {
    final data = {...payload, 'user_id': owner, 'request_id': requestId};
    try {
      return await client.from(table).insert(data).select().single();
    } on PostgrestException catch (error) {
      if (error.code != '23505') {
        rethrow;
      }
      final row = await client
          .from(table)
          .select()
          .eq('user_id', owner)
          .eq('request_id', requestId)
          .maybeSingle();
      if (row == null) rethrow;
      for (final entry in payload.entries) {
        final actual = row[entry.key];
        var equal = actual == entry.value;
        if (!equal &&
            actual is String &&
            entry.value is String &&
            (entry.key.endsWith('_at'))) {
          final left = DateTime.tryParse(actual);
          final right = DateTime.tryParse(entry.value as String);
          equal = left != null && right != null && left.isAtSameMomentAs(right);
        }
        if (!equal) {
          throw StateError('Request ID already used with different input.');
        }
      }
      return row;
    }
  });
}
