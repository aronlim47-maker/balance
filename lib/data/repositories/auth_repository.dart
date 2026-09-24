import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  User? get currentUser;
  Stream<AuthState> get authStateChanges;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signOut();
}
