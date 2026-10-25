import 'package:balance/core/shared_widgets/password_field.dart';
import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:balance/features/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<_RecordingAuth> _pumpRegister(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = _RecordingAuth();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: auth,
      child: MaterialApp(theme: AppTheme.dark, home: const RegisterScreen()),
    ),
  );
  return auth;
}

void main() {
  testWidgets('sign-up has two password fields, each with a show/hide button', (
    tester,
  ) async {
    await _pumpRegister(tester);

    expect(find.byType(PasswordField), findsNWidgets(2));
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsNWidgets(2));
  });

  testWidgets('mismatched passwords are caught before any request', (
    tester,
  ) async {
    final auth = await _pumpRegister(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ming');
    await tester.enterText(fields.at(1), 'student@example.com');
    await tester.enterText(fields.at(2), 'secret-pass');
    await tester.enterText(fields.at(3), 'secret-pazz');
    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.email, isNull);
  });

  testWidgets('matching passwords are sent once', (tester) async {
    final auth = await _pumpRegister(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ming');
    await tester.enterText(fields.at(1), 'student@example.com');
    await tester.enterText(fields.at(2), 'secret-pass');
    await tester.enterText(fields.at(3), 'secret-pass');
    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsNothing);
    expect(auth.email, 'student@example.com');
    expect(auth.password, 'secret-pass');
    expect(auth.displayName, 'Ming');
  });
}

class _RecordingAuth extends AuthViewModel {
  String? email;
  String? password;
  String? displayName;

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    this.email = email;
    this.password = password;
    this.displayName = displayName;
    return true;
  }
}
