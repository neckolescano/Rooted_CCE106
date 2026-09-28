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
import '../services/intro_cue.dart';
import '../widgets/kuwago_lockup.dart';
import 'main_shell.dart';

/// The kuwaGO login screen. All three options
/// now use real Firebase accounts: Google, email (create or sign in),
/// or an anonymous guest account.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // `late` = only created on the first button tap, not when the screen opens.
  late final _auth = AuthService();
  bool _busy = false;

  // Entrance: the sign unfurls under the kuwaGO lockup, then the buttons
  // rise in one by one. On app start it waits for the opening to reveal
  // this page (the opening flies the lockup onto the sign).
  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (IntroCue.stage.value == IntroStage.covering) {
      IntroCue.stage.addListener(_startWhenRevealed);
    } else {
      _entrance.forward();
    }
  }

  void _startWhenRevealed() {
    if (IntroCue.stage.value == IntroStage.covering) return;
    IntroCue.stage.removeListener(_startWhenRevealed);
    if (mounted) _entrance.forward();
  }

  @override
  void dispose() {
    IntroCue.stage.removeListener(_startWhenRevealed);
    _entrance.dispose();
    super.dispose();
  }

  /// Slides [child] up into place between [from] and [to] of the entrance.
  Widget _rise(double from, double to, Widget child) {
    return AnimatedBuilder(
      animation: _entrance,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOutBack.transform(((_entrance.value - from) / (to - from)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 36 * (1 - t)), child: child),
        );
      },
    );
  }

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
                    _TitleSign(entrance: _entrance),
                    const Spacer(flex: 3),
                    _rise(0.40, 0.75, PixelButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      onPressed: () => _run(_auth.signInWithGoogle),
                    )),
                    const SizedBox(height: AppSpacing.md),
                    _rise(0.50, 0.85, PixelButton(
                      label: 'Create Cozy Account',
                      onPressed: _emailFlow,
                    )),
                    const SizedBox(height: AppSpacing.md),
                    // On a dark plank so it stays readable over the grass.
                    _rise(0.60, 0.95, Semantics(
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
                    )),
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

/// The parchment sign in the sky: the kuwaGO lockup (kuwago perched on the
/// clock O — the same picture as the launch splash), the tagline and a
/// line about the app. The sign itself unfurls downward from under the
/// lockup; the lockup never moves, so the opening can land on it exactly.
class _TitleSign extends StatelessWidget {
  const _TitleSign({required this.entrance});

  final Animation<double> entrance;

  static double _seg(double v, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((v - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) {
        final e = entrance.value;
        final unfurl = _seg(e, 0, 0.38, Curves.easeOutBack);
        final words = _seg(e, 0.22, 0.55);
        return Stack(
          children: [
            // The board, unrolling from the top.
            Positioned.fill(
              child: Opacity(
                opacity: _seg(e, 0, 0.12),
                child: Transform.scale(
                  scaleY: unfurl.clamp(0.0, 1.2),
                  alignment: Alignment.topCenter,
                  child: const PixelPanel(style: PanelStyle.parchment, child: SizedBox.expand()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 20),
              child: Column(
                children: [
                  // Hidden until the opening has flown its copy in here.
                  ValueListenableBuilder<IntroStage>(
                    valueListenable: IntroCue.stage,
                    builder: (context, stage, child) =>
                        Opacity(opacity: stage == IntroStage.done ? 1 : 0, child: child),
                    // A third bigger than on the splash (2 dp per pixel);
                    // the opening grows it to this size as it lands.
                    child: KeyedSubtree(
                      key: IntroCue.loginLockupKey,
                      child: SizedBox.fromSize(
                        size: KuwagoLockup.size * (4 / 3),
                        child: const FittedBox(child: LiveKuwagoLockup()),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Opacity(
                    opacity: words,
                    child: Column(
                      children: [
                        Text(
                          '★ ${AppInfo.tagline.toUpperCase()} ★',
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
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
