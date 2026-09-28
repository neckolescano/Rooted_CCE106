import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../models/plant_model.dart';
import '../models/session_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/background_scene.dart';
import '../widgets/email_auth_dialog.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/pixel_sprite.dart';
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
  // `late` = only created on the first button tap, not when the screen opens.
  late final _auth = AuthService();
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
      plant.loadFrom(
        stageIndex: storage.savedPlantStage,
        wilted: storage.savedPlantWilted,
        speciesId: storage.savedPlantSpecies,
      );
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
          // Your meadow art fills the screen instead of plain cream.
          BackgroundScene(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    const _TitleSign(),
                    const Spacer(flex: 3),
                    PixelButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      onPressed: () => _run(_auth.signInWithGoogle),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PixelButton(
                      label: 'Create Cozy Account',
                      onPressed: _emailFlow,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // On a dark plank so it stays readable over the grass.
                    Semantics(
                      button: true,
                      label: 'Play as guest trainee',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => _run(_auth.signInAsGuest),
                        child: PixelPanel(
                          style: PanelStyle.dark,
                          backgroundColor: const Color(0xE63E2A1B),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'OR   ',
                                  style: AppText.small(color: AppColors.textCream.withValues(alpha: 0.7)),
                                ),
                                TextSpan(
                                  text: 'PLAY AS GUEST TRAINEE',
                                  style: AppText.small(color: AppColors.accentGold, weight: FontWeight.w800)
                                      .copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.accentGold),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: AppColors.overlay,
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Parchment sign with the grown sunflower as the logo, the title and
/// the tagline — sits in the sky above the meadow.
class _TitleSign extends StatelessWidget {
  const _TitleSign();

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: PanelStyle.parchment,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 20),
      child: Column(
        children: [
          const PixelSprite(
            'assets/images/plant/stages/fullgrown.png',
            size: 128,
            semanticLabel: 'Study Buddy sunflower logo',
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('STUDY BUDDY', style: AppTheme.pixelHeading(size: 22)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '★ PLANT EDITION ★',
            style: AppTheme.body(size: 14, color: AppColors.greenDeep, weight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Grow your virtual forest with every focus block.',
            textAlign: TextAlign.center,
            style: AppTheme.body(size: 13, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
