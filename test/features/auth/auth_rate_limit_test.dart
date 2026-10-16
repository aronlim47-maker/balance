// Sign-up on a tablet: "Could not complete the account request", then a lock
// with no hint how long it lasts. Rate limits now say how long to wait, and the
// button counts down instead of failing again.
import 'dart:async';

import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/core/utils/app_error_message.dart';
import 'package:balance/data/repositories/auth_repository.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _fallback = 'Please try again.';

String _message(AuthException error) =>
    AppErrorMessage.from(error, fallback: _fallback);

void main() {
  test('a wait in seconds is named and returned as a duration', () {
    const error = AuthException(
      'For security purposes, you can only request this after 42 seconds.',
      statusCode: '429',
      code: 'over_request_rate_limit',
    );
    expect(_message(error), contains('wait 42 seconds'));
    expect(AppErrorMessage.retryAfter(error), const Duration(seconds: 42));
    expect(
      AppErrorMessage.retryAfter(const AuthException('Invalid login')),
      isNull,
    );
  });

  test('email and request limits say how long to wait', () {
    expect(
      _message(
        const AuthException(
          'email rate limit exceeded',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      allOf(contains('up to an hour'), contains('spam folder')),
    );
    expect(
      _message(
        const AuthException(
          'Request rate limit reached',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
      ),
      contains('about 5 minutes'),
    );
    expect(
      _message(const AuthException('Error sending confirmation email')),
      contains('could not be sent'),
    );
  });

  test('an unknown auth error names its code but never its message', () {
    final message = _message(
      const AuthException('private server detail', code: 'unexpected_failure'),
    );
    expect(message, contains('code: unexpected_failure'));
    expect(message, isNot(contains('private server detail')));
    expect(
      _message(const AuthException('private server detail')),
      'Could not complete the account request. Please try again.',
    );
  });

  testWidgets('Sign up counts down and unlocks when the wait is over', (
    tester,
  ) async {
    final repo = _Auth()
      ..failure = const AuthException(
        'For security purposes, you can only request this after 3 seconds.',
        statusCode: '429',
        code: 'over_request_rate_limit',
      );
    final auth = AuthViewModel(repo);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.dark, home: const RegisterScreen()),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ming');
    await tester.enterText(fields.at(1), 'student@example.com');
    await tester.enterText(fields.at(2), 'secret-pass');
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(repo.signUps, 1);
    expect(find.textContaining('wait 3 seconds'), findsOneWidget);
    expect(find.text('Try again in 3s'), findsOneWidget);
    // While waiting, another tap does not reach the server.
    await tester.tap(find.text('Try again in 3s'));
    await tester.pump();
    expect(repo.signUps, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Try again in 2s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Sign up'), findsOneWidget);
    expect(auth.isWaiting, isFalse);

    repo.failure = null;
    await tester.tap(find.text('Sign up'));
    await tester.pump();
    expect(repo.signUps, 2);
    auth.dispose();
  });
}

class _Auth implements AuthRepository {
  final events = StreamController<AuthState>.broadcast(sync: true);
  Object? failure;
  int signUps = 0;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => events.stream;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    signUps++;
    if (failure != null) throw failure!;
    return AuthResponse();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
