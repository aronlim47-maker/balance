import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel([this._repository]) {
    _subscription = _repository?.authStateChanges.listen(
      (_) => notifyListeners(),
    );
  }

  final AuthRepository? _repository;
  StreamSubscription<AuthState>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;
  String? _noticeMessage;

  bool get isConfigured => _repository != null;
  bool get isAuthenticated => !isConfigured || _repository?.currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  String? get currentUserEmail => _repository?.currentUser?.email;
  String? get currentUserName {
    final value = _repository?.currentUser?.userMetadata?['display_name'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (_repository == null) return _notConfigured();
    return _run(() async {
      await _repository.signIn(email: email, password: password);
      return true;
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_repository == null) return _notConfigured();
    return _run(() async {
      final response = await _repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (response.session == null) {
        _noticeMessage = 'Account created. Check your email to verify it.';
      }
      return true;
    });
  }

  Future<bool> signOut() async {
    if (_repository == null) return _notConfigured();
    return _run(() async {
      await _repository.signOut();
      return true;
    });
  }

  Future<bool> _run(Future<bool> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Could not complete this request. Please try again.',
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _notConfigured() {
    _errorMessage =
        'Supabase is not configured. Add the project URL and publishable key.';
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
