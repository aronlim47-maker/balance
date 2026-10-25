import 'package:balance/core/shared_widgets/password_field.dart';
import 'package:balance/core/theme/app_theme.dart';
import 'package:balance/features/auth/account_help_screen.dart';
import 'package:balance/features/auth/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Future<_RecordingAuth> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = _RecordingAuth();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: auth,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const AccountHelpScreen(resetPassword: true),
      ),
    ),
  );
  return auth;
}

void main() {
  testWidgets('new-password screen has two fields, each with an eye button', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(PasswordField), findsNWidgets(2));
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Show password').first);
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('short or mismatched passwords are caught before any request', (
    tester,
  ) async {
    final auth = await _pump(tester);
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'short');
    await tester.enterText(fields.at(1), 'short');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(auth.updated, isNull);

    await tester.enterText(fields.at(0), 'long-enough-1');
    await tester.enterText(fields.at(1), 'long-enough-2');
    await tester.tap(find.text('Update password'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.updated, isNull);
  });

  testWidgets('matching passwords are sent once', (tester) async {
    final auth = await _pump(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'long-enough-1');
    await tester.enterText(fields.at(1), 'long-enough-1');
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(auth.updated, 'long-enough-1');
  });
}

class _RecordingAuth extends AuthViewModel {
  String? updated;

  @override
  Future<bool> updatePassword(String password) async {
    updated = password;
    return true;
  }
}
