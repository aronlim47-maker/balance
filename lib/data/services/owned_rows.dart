import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_user.dart';

/// Continue until an empty page: a server row cap can make a page short.
/// Stable ordering and owner checks prevent silent truncation/account mixing.
Future<List<Map<String, dynamic>>> readOwnedRows(
  SupabaseClient client,
  PostgrestTransformBuilder<PostgrestList> Function(String owner) query, {
  int maxRows = 10000,
}) async {
  final owner = requireAuthenticatedUserId(client);
  final result = <Map<String, dynamic>>[];
  while (true) {
    if (requireAuthenticatedUserId(client) != owner) {
      throw StateError('Account changed. Reload this view.');
    }
    final rows = await query(owner).range(result.length, result.length + 99);
    if (requireAuthenticatedUserId(client) != owner) {
      throw StateError('Account changed. Reload this view.');
    }
    if (rows.isEmpty) return result;
    if (result.length + rows.length > maxRows) {
      throw StateError('Too much history. Choose a shorter date range.');
    }
    result.addAll(rows);
  }
}
