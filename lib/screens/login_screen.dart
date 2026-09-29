import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../models/plant_model.dart';
import '../models/session_model.dart';
import '../services/auth_service.dart';
import '../services/intro_cue.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/email_auth_dialog.dart';
import '../widgets/login_scene.dart';
import '../widgets/owl_mascot.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';
import 'main_shell.dart';

/// The kuwaGO login screen: a morning garden under a wooden pergola.
///
/// Its entrance is a little story: kuwago knocks the hook on the beam, the
/// kuwaGO sign drops down on its chains and swings, kuwago lands on top
/// ("Hoo! Welcome!"), then the buttons rise in. On app start the opening
/// (widgets/clock_intro.dart) flies kuwago from the splash straight to the
/// hook, so it all flows on from the splash; any other time (e.g. after
/// signing out) kuwago flies in by itself first. Tap kuwago to make it hop
/// and swing the sign.
///
/// All three sign-in options use real Firebase accounts: Google, email
/// (create or sign in), or an anonymous guest account.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// ---- Entrance timing (ms, after kuwago reaches the hook) ----
const double _flyInMs = 650; // only when there was no opening to bring kuwago
const _knock = (0.0, 170.0);
const _drop = (170.0, 630.0);
const _owlToSign = (250.0, 850.0);
const _words = (700.0, 1050.0);
const _welcome = (900.0, 2500.0);
const double _storyMs = 2600;

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // `late` = only created on the first button tap, not when the screen opens.
  late final _auth = AuthService();
  bool _busy = false;

  /// Does kuwago still have to fly in (no opening brought it)?
  late final bool _flyIn = IntroCue.stage.value == IntroStage.done;
  late final double _lead = _flyIn ? _flyInMs : 0;

  late final AnimationController _story =
      AnimationController(vsync: this, duration: Duration(milliseconds: (_lead + _storyMs).round()));
  // Ambient clock: clouds, sun rays, ivy, butterflies, leaves, blinking.
  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();
  // kuwago's hop (and the sign's extra swing) when tapped.
  late final AnimationController _tap = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  final _leaves = LeafDrift.scatter(Random(12), 9);

  @override
  void initState() {
    super.initState();
    if (_flyIn) {
      _story.forward();
    } else {
      // The opening is flying kuwago to the hook; start when it arrives.
      IntroCue.stage.addListener(_startWhenDelivered);
      // Safety net: if the opening never reports back (it normally takes
      // ~1.5 s), start anyway so the buttons can never stay hidden.
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (mounted && !_story.isAnimating && _story.value == 0) {
          debugPrint('[Login] opening never handed over — starting the entrance anyway');
          IntroCue.stage.removeListener(_startWhenDelivered);
          _story.forward();
        }
      });
    }
  }

  void _startWhenDelivered() {
    if (IntroCue.stage.value != IntroStage.done) return;
    IntroCue.stage.removeListener(_startWhenDelivered);
    if (mounted && !_story.isAnimating && _story.value == 0) _story.forward();
  }

  @override
  void dispose() {
    IntroCue.stage.removeListener(_startWhenDelivered);
    _story.dispose();
    _ambient.dispose();
    _tap.dispose();
    super.dispose();
  }

  void _tapOwl() {
    if (_story.value * _story.duration!.inMilliseconds >= _lead + _owlToSign.$2) _tap.forward(from: 0);
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
      notes.loadFrom(storage.savedNotes, savedMaterial: storage.savedStudyMaterial);
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

  static double _seg(double v, (double, double) s, [Curve c = Curves.linear]) =>
      c.transform(((v - s.$1) / (s.$2 - s.$1)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_story, _ambient, _tap]),
            builder: (context, _) => LayoutBuilder(
              builder: (context, box) => _scene(LoginLayout(box.biggest, padding), padding),
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

  Widget _scene(LoginLayout l, EdgeInsets padding) {
    final started = _story.value > 0 || _story.isAnimating;
    final ms = _story.value * (_lead + _storyMs) - _lead; // 0 = kuwago at the hook
    final sec = _ambient.value * 120;
    final hook = l.hook;
    final chainLen = l.chainLen;
    const signW = LoginLayout.signW, signH = LoginLayout.signH, owlSize = LoginLayout.owlSize;

    // ---- Knock: the beam shudders, leaves shake loose, the screen thumps ----
    final knockT = _seg(ms, _knock);
    final beamShake = knockT > 0 && knockT < 1 ? sin(knockT * pi * 6) * 2 * (1 - knockT) : 0.0;
    final sinceLand = ms - _drop.$2;
    final thump = sinceLand > -120 && sinceLand < 180 ? sin(sinceLand / 18) * 2.5 * (1 - (sinceLand + 120) / 300) : 0.0;

    // ---- The sign drops on its chains, then swings (damped pendulum) ----
    final dropY = started
        ? -(hook.dy + chainLen + signH + 40) * (1 - Curves.bounceOut.transform(_seg(ms, _drop)))
        : -(hook.dy + chainLen + signH + 40);
    double swing = 0;
    if (ms > _drop.$2) {
      final t = (ms - _drop.$2) / 1000;
      swing += 0.2 * exp(-t / 0.9) * sin(2 * pi * t / 1.15);
    }
    if (_tap.isAnimating) {
      final t = _tap.value * 2.6;
      swing += 0.17 * exp(-t / 0.8) * sin(2 * pi * t / 1.15);
    }
    swing += 0.012 * sin(2 * pi * sec / 4.2); // a gentle breeze

    Offset signPoint(Offset local) {
      final p = Offset(local.dx, local.dy + dropY);
      return hook + Offset(p.dx * cos(swing) - p.dy * sin(swing), p.dx * sin(swing) + p.dy * cos(swing));
    }

    // ---- kuwago ----
    Offset? owlCenter; // null = sitting on the sign (drawn with it)
    bool flying = false;
    int look = 0;
    if (!started) {
      owlCenter = null; // not here yet (the opening is bringing it)
    } else if (ms < 0) {
      // Flying in from the top right.
      final t = Curves.easeOutCubic.transform(((ms + _lead) / _lead).clamp(0.0, 1.0));
      owlCenter = Offset.lerp(Offset(l.width + 40, hook.dy - 30), l.hookPerch, t)! + Offset(0, -30 * sin(pi * t));
      flying = true;
      look = -1;
    } else if (ms < _owlToSign.$1) {
      owlCenter = l.hookPerch + Offset(10 * sin(pi * knockT * 2).abs(), 0); // knock knock!
      flying = true;
      look = 1;
    } else if (ms < _owlToSign.$2) {
      final t = _seg(ms, _owlToSign, Curves.easeInOutCubic);
      final target = signPoint(l.perch) - const Offset(0, owlSize / 2 - 6);
      owlCenter = Offset.lerp(l.hookPerch, target, t)! + Offset(0, -30 * sin(pi * t));
      flying = true;
    }
    final onSign = started && ms >= _owlToSign.$2;
    final wingsUp = flying && (ms ~/ 90).isEven;
    final blink = (sec * 1000 % 3100) < 130;
    final hop = _tap.isAnimating ? sin(pi * min(1.0, _tap.value * 2.6 / 0.45)) * 12 : 0.0;
    final hopWings = _tap.isAnimating && _tap.value * 2.6 < 0.45 && (_tap.value * 26).floor().isEven;
    final landS = _seg(ms, (_owlToSign.$2, _owlToSign.$2 + 260));
    final squash = landS > 0 && landS < 1 ? 1 - 0.16 * sin(pi * landS) : 1.0;
    final saysWelcome = ms > _welcome.$1 && ms < _welcome.$2;
    final saysHoo = _tap.isAnimating && _tap.value * 2.6 < 0.9;

    Widget owl({required bool wings}) => OwlSprite(
          size: owlSize,
          perch: false,
          look: onSign ? -1 : look,
          blink: blink && !flying,
          wingsUp: wings,
        );

    final shake = Offset(beamShake + thump * 0.4, thump);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: shake,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: LoginSkyPainter()))),
              Positioned.fill(child: CustomPaint(painter: LoginSunCloudsPainter(sec: sec))),
              Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: LoginLandPainter()))),
              Positioned.fill(
                child: CustomPaint(painter: LoginPergolaPainter(beamTop: l.beamTop, sec: sec, shake: beamShake)),
              ),

              // Where the opening delivers kuwago (it hovers here to knock).
              Positioned.fromRect(
                rect: Rect.fromCenter(center: l.hookPerch, width: owlSize, height: owlSize),
                child: KeyedSubtree(key: IntroCue.loginOwlKey, child: const SizedBox.expand()),
              ),

              // Chains + sign + kuwago, swinging around the hook.
              if (started)
                Positioned(
                  left: hook.dx - signW / 2,
                  top: hook.dy,
                  width: signW,
                  height: chainLen + signH + dropY.abs() + 80,
                  child: Transform.rotate(
                    angle: swing,
                    alignment: Alignment.topCenter,
                    child: Transform.translate(
                      offset: Offset(0, dropY),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            width: signW,
                            height: chainLen + 8,
                            child: CustomPaint(painter: SignChainsPainter(chainLen: chainLen, spread: signW / 2 - 18)),
                          ),
                          Positioned(left: 0, top: chainLen, width: signW, height: signH, child: const HangingSign()),
                          if (onSign)
                            Positioned(
                              left: signW / 2 + l.perch.dx - owlSize / 2,
                              top: chainLen - owlSize * 21 / 24 + 2 - hop,
                              child: Semantics(
                                button: true,
                                label: 'kuwago the owl',
                                child: GestureDetector(
                                  onTap: _tapOwl,
                                  child: Transform.scale(
                                    scaleY: squash,
                                    scaleX: 2 - squash,
                                    alignment: Alignment.bottomCenter,
                                    child: owl(wings: hopWings),
                                  ),
                                ),
                              ),
                            ),
                          if (onSign && (saysWelcome || saysHoo))
                            Positioned(
                              left: signW / 2 + l.perch.dx + 12,
                              top: chainLen - owlSize - 20 - hop,
                              child: OwlBubble(saysHoo ? 'Hoo!' : 'Hoo! Welcome!'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (knockT > 0 && knockT < 1)
                Positioned.fill(child: CustomPaint(painter: KnockSparkPainter(center: hook + const Offset(0, 4), t: knockT))),
              Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: LoginBushesPainter()))),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: LoginLifePainter(
                      sec: sec,
                      leaves: _leaves,
                      burstT: started && ms > _knock.$1 ? (ms - _knock.$1) / 1000 : -1,
                      burstFrom: Offset(l.width / 2, l.beamTop + LoginLayout.beamH),
                      meadowTop: l.meadowTop,
                    ),
                  ),
                ),
              ),
              // kuwago in flight (before it sits on the sign).
              if (owlCenter != null)
                Positioned(
                  left: owlCenter.dx - owlSize / 2,
                  top: owlCenter.dy - owlSize / 2,
                  child: IgnorePointer(child: owl(wings: wingsUp)),
                ),
            ],
          ),
        ),

        // The line under the sign.
        Positioned(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: hook.dy + chainLen + signH + 18,
          child: Opacity(
            opacity: started ? _seg(ms, _words) : 0,
            child: Text(
              'Grow your virtual forest\nwith every focus block.',
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 14, color: AppColors.textDark, weight: FontWeight.w800),
            ),
          ),
        ),

        // The buttons, rising onto the meadow one by one.
        Positioned(
          left: 28,
          right: 28,
          bottom: padding.bottom + 22,
          child: Column(
            children: [
              _rise(started, ms, 750, const RibbonTag('★ JOIN THE GARDEN ★')),
              const SizedBox(height: AppSpacing.md),
              _rise(
                started,
                ms,
                830,
                PixelButton(
                  label: 'Continue with Google',
                  icon: Icons.g_mobiledata,
                  onPressed: () => _run(_auth.signInWithGoogle),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _rise(started, ms, 930, PixelButton(label: 'Create Cozy Account', onPressed: _emailFlow)),
              const SizedBox(height: AppSpacing.md),
              _rise(
                started,
                ms,
                1030,
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Rises [child] into place 350 ms after [start] (ms of the entrance).
  Widget _rise(bool started, double ms, double start, Widget child) {
    final t = started ? Curves.easeOutBack.transform(((ms - start) / 350).clamp(0.0, 1.0)) : 0.0;
    return IgnorePointer(
      ignoring: t < 0.5,
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 40 * (1 - t)), child: child),
      ),
    );
  }
}
