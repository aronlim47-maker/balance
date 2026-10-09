import 'package:supabase_flutter/supabase_flutter.dart';

String requireAuthenticatedUserId(SupabaseClient client) {
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Authentication is required for this operation.');
  }
  return userId;
}

void ensureAuthenticatedUserUnchanged(SupabaseClient client, String expected) {
  if (client.auth.currentUser?.id != expected) {
    throw StateError('Account changed. Reload this view.');
  }
}
