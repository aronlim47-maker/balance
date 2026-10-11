import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('sign-in sends the typed email and password separately', (
    tester,
  ) async {
    final auth = _RecordingAuth();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );

    // One email field and one password field, in that order.
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    expect(
      find.descendant(of: fields.at(0), matching: find.text('Email')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fields.at(1), matching: find.text('Password')),
      findsOneWidget,
    );

    await tester.enterText(fields.at(0), 'student@example.com');
    await tester.enterText(fields.at(1), 'secret-pass');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(auth.email, 'student@example.com');
    expect(auth.password, 'secret-pass');
  });

  testWidgets('an invalid email is caught before any request', (tester) async {
    final auth = _RecordingAuth();
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'not-an-email');
    await tester.enterText(fields.at(1), 'secret-pass');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(auth.email, isNull);
  });
}

class _RecordingAuth extends AuthViewModel {
  String? email;
  String? password;

  @override
  Future<bool> signIn({required String email, required String password}) async {
    this.email = email;
    this.password = password;
    return true;
  }
}
