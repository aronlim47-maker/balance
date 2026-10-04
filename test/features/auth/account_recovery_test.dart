import 'dart:async';

import 'package:balance/core/router/app_router.dart';
import 'package:balance/data/repositories/auth_repository.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/auth/account_help_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Auth implements AuthRepository {
  final events = StreamController<AuthState>.broadcast(sync: true);
  @override
  User? currentUser;
  int resetRequests = 0;
  int verificationRequests = 0;
  int passwordUpdates = 0;
  Completer<void>? pending;
  Object? failure;
  @override
  Stream<AuthState> get authStateChanges => events.stream;
  @override
  Future<void> requestPasswordReset(String email) async {
    resetRequests++;
    if (failure != null) throw failure!;
    await pending?.future;
  }

  @override
  Future<void> resendVerification(String email) async {
    verificationRequests++;
  }

  @override
  Future<void> updatePassword(String password) async {
    passwordUpdates++;
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
    events.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void recover() {
    currentUser = User(
      id: 'a',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-10-04T00:00:00Z',
    );
    events.add(
      AuthState(
        AuthChangeEvent.passwordRecovery,
        Session(accessToken: 'test', tokenType: 'bearer', user: currentUser!),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('normal login cannot authorize a password recovery update', () async {
    final repo = _Auth();
    final model = AuthViewModel(repo);
    expect(await model.updatePassword('new-password'), false);
    expect(repo.passwordUpdates, 0);
    repo.recover();
    expect(model.isRecoveringPassword, true);
    expect(await model.updatePassword('new-password'), true);
    expect(repo.passwordUpdates, 1);
    expect(model.isRecoveringPassword, false);
    model.dispose();
    await repo.events.close();
  });

  test(
    'duplicate requests are suppressed and disposal during a request is safe',
    () async {
      final repo = _Auth()..pending = Completer<void>();
      final model = AuthViewModel(repo);
      final first = model.requestPasswordReset('a@example.com');
      expect(await model.requestPasswordReset('a@example.com'), false);
      expect(repo.resetRequests, 1);
      model.dispose();
      repo.pending!.complete();
      await first;
      await repo.events.close();
    },
  );

  test('failed email requests show safe guidance', () async {
    final repo = _Auth()
      ..failure = const AuthException('private server detail');
    final model = AuthViewModel(repo);
    expect(await model.requestPasswordReset('a@example.com'), false);
    expect(model.errorMessage, isNot(contains('private server detail')));
    expect(model.noticeMessage, isNull);
    model.dispose();
    await repo.events.close();
  });

  testWidgets(
    'email validation blocks requests and resend has an honest notice',
    (tester) async {
      final repo = _Auth();
      final model = AuthViewModel(repo);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(home: AccountHelpScreen()),
        ),
      );
      await tester.tap(find.text('Send password reset link'));
      await tester.pump();
      expect(repo.resetRequests, 0);
      await tester.enterText(find.byType(TextFormField), 'a@example.com');
      await tester.tap(find.text('Resend verification email'));
      await tester.pumpAndSettle();
      expect(repo.verificationRequests, 1);
      expect(find.textContaining('If verification is needed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      await repo.events.close();
    },
  );

  testWidgets(
    'router guards reset page and requires the verified recovery event',
    (tester) async {
      final repo = _Auth();
      final model = AuthViewModel(repo);
      final router = buildAppRouter(model);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.go(AppRoutes.resetPassword);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      repo.recover();
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.resetPassword,
      );
      await model.signOut();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      model.dispose();
      await repo.events.close();
    },
  );
}
