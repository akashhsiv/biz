import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/app_variant.dart';
import '../../core/network/api_result.dart';
import '../../shared/widgets/password_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_username.text.isEmpty || _password.text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authControllerProvider.notifier).login(_username.text.trim(), _password.text);

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case ApiSuccess():
        break; // router redirect handles navigation once isAuthenticated flips true.
      case ApiFailure(message: final msg):
        setState(() => _error = msg);
      case ApiNetworkError(message: final msg):
        setState(() => _error = 'Could not reach the Host: $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.storefront_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(AppVariant.appTitle, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Log In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
