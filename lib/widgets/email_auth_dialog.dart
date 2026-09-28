import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_scroll.dart';

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
    // Square corners + 2px dark border, same as the pixel panels.
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide:
          BorderSide(color: AppColors.panelDark, width: AppBorders.width),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: AppTheme.body(
          size: 13, color: AppColors.textMuted, weight: FontWeight.w600),
      floatingLabelStyle: AppTheme.body(
          size: 13, color: AppColors.panelMedium, weight: FontWeight.w800),
      filled: true,
      fillColor: const Color(0xFFFFF8EC),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.panelMedium, width: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: PixelScroll(
        seal: const WaxSeal(icon: Icons.mail_outline),
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
                TextField(
                    controller: _username, decoration: _decoration('Username')),
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
                  style: AppText.small(color: AppColors.dangerText),
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
                  _isCreate
                      ? 'Already have an account? Sign in'
                      : 'New here? Create an account',
                  style: AppTheme.body(
                      size: 12,
                      color: AppColors.panelMedium,
                      weight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: AppText.small()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
