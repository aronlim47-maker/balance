import 'package:flutter/material.dart';

/// Password input with a show/hide eye button.
///
/// Starts hidden. The eye button has a spoken label ("Show password" /
/// "Hide password") and a 48 px touch target, so it works with TalkBack.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.labelText = 'Password',
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _hidden,
    enableSuggestions: false,
    autocorrect: false,
    autofillHints: widget.autofillHints,
    textInputAction: widget.textInputAction,
    onFieldSubmitted: widget.onFieldSubmitted,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.labelText,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
