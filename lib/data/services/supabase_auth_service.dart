import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';

class SupabaseAuthService implements AuthRepository {
  SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _client.auth.signUp(
    email: email.trim(),
    password: password,
    data: {'display_name': displayName.trim()},
  );

  @override
  Future<void> signOut() => _client.auth.signOut();
}
