import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../models/plant_model.dart';
import '../models/session_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/email_auth_dialog.dart';
import '../widgets/pixel_button.dart';
import 'main_shell.dart';

/// The "Study Buddy — Plant Edition" login screen. All three options
/// now use real Firebase accounts: Google, email (create or sign in),
/// or an anonymous guest account.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _busy = false;

  /// Runs a sign-in, then loads that user's saved data and enters the app.
  Future<void> _run(Future<User> Function() signIn, {String? username}) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final user = await signIn();
      if (!mounted) return;

      final storage = context.read<StorageService>();
      final plant = context.read<PlantModel>();
      final notes = context.read<NotesModel>();
      final session = context.read<SessionModel>();

      await storage.attachUser(
        uid: user.uid,
        displayName: username ?? user.displayName,
        email: user.email,
        isGuest: user.isAnonymous,
      );

      // The models were created before anyone was signed in, so point
      // them at this user's data now.
      plant.loadFrom(stageIndex: storage.savedPlantStage, wilted: storage.savedPlantWilted);
      notes.loadFrom(storage.savedNotes);
      session.reset();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.friendlyError(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailFlow() async {
    final result = await showDialog<EmailAuthResult>(
      context: context,
      builder: (_) => const EmailAuthDialog(),
    );
    if (result == null) return;

    if (result.isCreate) {
      await _run(
        () => _auth.createAccount(
          email: result.email,
          password: result.password,
          username: result.username,
        ),
        username: result.username,
      );
    } else {
      await _run(() => _auth.signInWithEmail(email: result.email, password: result.password));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
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
                    onPressed: () => _run(_auth.signInWithGoogle),
                  ),
                  const SizedBox(height: 12),
                  PixelButton(
                    label: 'Create Cozy Account',
                    onPressed: _emailFlow,
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
                    onTap: () => _run(_auth.signInAsGuest),
                    child: Text(
                      'PLAY AS GUEST TRAINEE',
                      style: AppTheme.body(size: 12, weight: FontWeight.bold)
                          .copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Color(0x55000000),
                  child: Center(child: CircularProgressIndicator(color: AppColors.panelMedium)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
