import 'dart:async';

import '../../core/state/lifecycle_notifier.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/app_error_message.dart';
import '../../data/repositories/auth_repository.dart';

class AuthViewModel extends LifecycleNotifier {
  AuthViewModel([this._repository]) {
    _subscription = _repository?.authStateChanges.listen(
      (state) {
        if (isDisposed) return;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _recoveryUserId = state.session?.user.id;
        } else if (state.event == AuthChangeEvent.signedOut) {
          _recoveryUserId = null;
        } else if (state.event == AuthChangeEvent.signedIn) {
          _recoveryUserId = null;
        }
        notifyListeners();
      },
      onError: (Object error) {
        if (isDisposed) return;
        _errorMessage = AppErrorMessage.from(
          error,
          fallback: 'This email link could not be verified. Request a new link and try again.',
        );
        notifyListeners();
      },
    );
  }

  final AuthRepository? _repository;
  StreamSubscription<AuthState>? _subscription;
  bool _isLoading = false;
  String? _errorMessage;
  String? _noticeMessage;
  String? _recoveryUserId;
  bool get isRecoveringPassword =>
      _recoveryUserId != null && _recoveryUserId == currentUserId;

  bool get isConfigured => _repository != null;
  String? get currentUserId => _repository?.currentUser?.id;
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
        _noticeMessage = 'Check your email to verify your account. If you already have an account, sign in or use Account help.';
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

  Future<bool> requestPasswordReset(String email) async {
    if (_repository == null) return _notConfigured();
    return _run(() async {
      await _repository.requestPasswordReset(email);
      _noticeMessage = 'If this email has an account, a reset link will arrive shortly. Check your inbox and spam folder.';
      return true;
    });
  }

  Future<bool> resendVerification(String email) async {
    if (_repository == null) return _notConfigured();
    return _run(() async {
      await _repository.resendVerification(email);
      _noticeMessage = 'If verification is needed, a new link will arrive shortly. Check your inbox and spam folder.';
      return true;
    });
  }

  Future<bool> updatePassword(String password) async {
    if (_repository == null) return _notConfigured();
    if (!isRecoveringPassword || password.length < 8) return false;
    final owner = currentUserId;
    return _run(() async {
      await _repository.updatePassword(password);
      if (isDisposed || owner != currentUserId) return false;
      _recoveryUserId = null;
      _noticeMessage = 'Password updated.';
      return true;
    });
  }

  Future<bool> _run(Future<bool> Function() action) async {
    if (isDisposed || _isLoading) return false;
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
