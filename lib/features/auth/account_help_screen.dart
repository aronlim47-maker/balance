import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth_view_model.dart';

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
          title: Text(reset ? 'Choose a new password' : 'Account help'),
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
                        const Text(
                          'Enter your account email to receive a link.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch((value ?? '').trim())
                              ? null
                              : 'Enter a valid email address.',
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'New password',
                          ),
                          validator: (value) => (value ?? '').length >= 8
                              ? null
                              : 'Use at least 8 characters.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmation,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          validator: (value) => value == _password.text
                              ? null
                              : 'Passwords do not match.',
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
                          onPressed: auth.isLoading ? null : () => _send(false),
                          child: const Text('Send password reset link'),
                        ),
                        TextButton(
                          onPressed: auth.isLoading ? null : () => _send(true),
                          child: const Text('Resend verification email'),
                        ),
                      ] else ...[
                        FilledButton(
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  if (!_form.currentState!.validate()) return;
                                  await auth.updatePassword(_password.text);
                                },
                          child: const Text('Update password'),
                        ),
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => auth.signOut(),
                          child: const Text('Cancel and sign out'),
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
