import 'package:supabase_flutter/supabase_flutter.dart';

String requireAuthenticatedUserId(SupabaseClient client) {
  final userId = client.auth.currentUser?.id;
  if (userId == null) {
    throw StateError('Authentication is required for this operation.');
  }
  return userId;
}
