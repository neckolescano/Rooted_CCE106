import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';

/// What the student typed into the email dialog.
class EmailAuthResult {
  const EmailAuthResult({
    required this.isCreate,
    required this.email,
    required this.password,
    required this.username,
  });

  final bool isCreate; // true = new account, false = signing in
  final String email;
  final String password;
  final String username;
}

/// One dialog for both "Create Cozy Account" and "Sign in", since a
/// returning student needs a way back into the account they made.
class EmailAuthDialog extends StatefulWidget {
  const EmailAuthDialog({super.key});

  @override
  State<EmailAuthDialog> createState() => _EmailAuthDialogState();
}

class _EmailAuthDialogState extends State<EmailAuthDialog> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isCreate = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _username.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (_isCreate && username.isEmpty) {
      setState(() => _error = 'Pick a username for your garden.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = "That email address doesn't look right.");
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password needs at least 6 characters.');
      return;
    }

    Navigator.of(context).pop(EmailAuthResult(
      isCreate: _isCreate,
      email: email,
      password: password,
      username: username,
    ));
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTheme.body(size: 12, color: AppColors.textDark.withOpacity(0.6)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.6),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.panelDark, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.panelDark, width: 3),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isCreate ? 'CREATE ACCOUNT' : 'WELCOME BACK',
              textAlign: TextAlign.center,
              style: AppTheme.pixelHeading(size: 13),
            ),
            const SizedBox(height: 16),
            if (_isCreate) ...[
              TextField(controller: _username, decoration: _decoration('Username')),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoration('Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: _decoration('Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 11, color: const Color(0xFFB23B2E)),
              ),
            ],
            const SizedBox(height: 16),
            PixelButton(
              label: _isCreate ? 'Create Account' : 'Sign In',
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _isCreate = !_isCreate;
                _error = null;
              }),
              child: Text(
                _isCreate ? 'Already have an account? Sign in' : 'New here? Create an account',
                style: AppTheme.body(size: 12, color: AppColors.panelMedium, weight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTheme.body(size: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
