import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_button.dart';
import 'main_shell.dart';

/// The "Study Buddy — Plant Edition" splash/login screen.
/// For now all three options just take the student straight into the
/// app (no real auth wired up yet) — swap the onPressed callbacks for
/// real sign-in logic later.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _enterApp(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Little plant logo circle
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3D7BE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_florist, size: 48, color: AppColors.panelMedium),
              ),
              const SizedBox(height: 24),
              Text('STUDY BUDDY', style: AppTheme.pixelHeading(size: 24)),
              const SizedBox(height: 8),
              Text(
                '★ PLANT EDITION ★',
                style: AppTheme.body(size: 14, color: AppColors.accentGreen, weight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Grow your virtual forest with every focus block.',
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 13),
              ),
              const Spacer(flex: 3),
              PixelButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                onPressed: () => _enterApp(context),
              ),
              const SizedBox(height: 12),
              PixelButton(
                label: 'Create Cozy Account',
                onPressed: () => _enterApp(context),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.panelDark.withOpacity(0.4))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('OR', style: AppTheme.body(size: 12)),
                  ),
                  Expanded(child: Divider(color: AppColors.panelDark.withOpacity(0.4))),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _enterApp(context),
                child: Text(
                  'PLAY AS GUEST TRAINEE',
                  style: AppTheme.body(
                    size: 12,
                    weight: FontWeight.bold,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
