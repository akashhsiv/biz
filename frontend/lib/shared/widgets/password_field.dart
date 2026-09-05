import 'package:flutter/material.dart';

/// A TextField for password entry with an eye icon to toggle visibility - a plain
/// `obscureText: true` TextField gives no way to check what was actually typed before submitting.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String>? onSubmitted;

  const PasswordField({
    super.key,
    required this.controller,
    this.labelText = 'Password',
    this.onSubmitted,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          tooltip: _obscured ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
