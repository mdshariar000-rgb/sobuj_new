import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/core_providers.dart';
import '../../services/api_exception.dart';
import 'widgets/auth_error_banner.dart';

/// "Forgot password?": email a 6-digit code, then enter it with a new
/// password. Pops back to Log In once the password is reset.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeSent = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final api = ref.read(apiClientProvider);
    final email = _emailController.text.trim();
    try {
      if (!_codeSent) {
        await api.sendPasswordResetCode(email);
        if (mounted) setState(() => _codeSent = true);
      } else {
        await api.resetPassword(
          email: email,
          code: _codeController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset. Log in with your new password.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _codeSent
                    ? 'If an account exists for ${_emailController.text.trim()}, '
                          'we have emailed it a 6-digit code. Enter it below '
                          'with your new password.'
                    : 'Enter your email and we will send you a code to reset '
                          'your password.',
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) ...[
                AuthErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('reset-email-field'),
                controller: _emailController,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email.'
                    : null,
              ),
              if (_codeSent) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('reset-code-field'),
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(labelText: '6-digit code'),
                  validator: (value) => (value == null || value.length != 6)
                      ? 'Enter the 6-digit code from the email.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('reset-password-field'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => (value == null || value.length < 8)
                      ? 'Password must be at least 8 characters.'
                      : null,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('reset-submit'),
                onPressed: _isSubmitting ? null : _submit,
                child: Text(_codeSent ? 'Reset password' : 'Send code'),
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                          _codeSent = false;
                          _codeController.clear();
                        }),
                  child: const Text('Send a new code'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
