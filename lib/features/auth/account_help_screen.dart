import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth_view_model.dart';
import '../../core/l10n/tr.dart';

/// Supabase verifies email links before the recovery route becomes available.
class AccountHelpScreen extends StatefulWidget {
  const AccountHelpScreen({super.key, this.resetPassword = false});
  final bool resetPassword;

  @override
  State<AccountHelpScreen> createState() => _AccountHelpScreenState();
}

class _AccountHelpScreenState extends State<AccountHelpScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _send(bool verification) async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthViewModel>();
    if (verification) {
      await auth.resendVerification(_email.text);
    } else {
      await auth.requestPasswordReset(_email.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final reset = widget.resetPassword;
    // Reached with context.go, so there is no route below: without this the
    // Android back gesture would close the app instead of returning to sign-in.
    return PopScope(
      canPop: reset,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/login');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(reset ? 'Choose a new password'.tr : 'Account help'.tr),
          leading: reset
              ? null
              : BackButton(onPressed: () => context.go('/login')),
          automaticallyImplyLeading: !reset,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!reset) ...[
                        Text('Enter your account email to receive a link.'.tr),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(labelText: 'Email'.tr),
                          validator: (value) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch((value ?? '').trim())
                              ? null
                              : 'Enter a valid email address.'.tr,
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'New password'.tr,
                          ),
                          validator: (value) => (value ?? '').length >= 8
                              ? null
                              : 'Use at least 8 characters.'.tr,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmation,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Confirm password'.tr,
                          ),
                          validator: (value) => value == _password.text
                              ? null
                              : 'Passwords do not match.'.tr,
                        ),
                      ],
                      if (auth.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            auth.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (auth.noticeMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(auth.noticeMessage!),
                        ),
                      const SizedBox(height: 24),
                      if (!reset) ...[
                        FilledButton(
                          onPressed: auth.isLoading || auth.isWaiting
                              ? null
                              : () => _send(false),
                          child: Text(
                            auth.isWaiting
                                ? 'Try again in ${auth.retrySecondsLeft}s'.tr
                                : 'Send password reset link'.tr,
                          ),
                        ),
                        TextButton(
                          onPressed: auth.isLoading || auth.isWaiting
                              ? null
                              : () => _send(true),
                          child: Text('Resend verification email'.tr),
                        ),
                      ] else ...[
                        FilledButton(
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  if (!_form.currentState!.validate()) return;
                                  await auth.updatePassword(_password.text);
                                },
                          child: Text('Update password'.tr),
                        ),
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => auth.signOut(),
                          child: Text('Cancel and sign out'.tr),
                        ),
                      ],
                      if (auth.isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
