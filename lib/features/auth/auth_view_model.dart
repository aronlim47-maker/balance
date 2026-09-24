import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        _noticeMessage = '账户已建立，请先检查邮箱并完成验证。';
      }
      return true;
    });
  }

  Future<void> signOut() async {
    if (_repository == null) return;
    await _repository.signOut();
  }

  Future<bool> _run(Future<bool> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      return await action();
    } on AuthException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = '操作失败，请稍后再试。';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _notConfigured() {
    _errorMessage = '尚未配置 Supabase。请先加入项目 URL 和 publishable key。';
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
