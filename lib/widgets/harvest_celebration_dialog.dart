import 'dart:math';
import 'package:flutter/material.dart';
import '../models/garden_progress.dart';
import '../models/plant_catalog.dart' show PlantAura;
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_panel.dart';
import 'plant_aura.dart';

/// Shown once a plant hits its final growth stage, using your hand-drawn
/// scroll (its "CONGRATULATIONS!" banner is baked into the art).
///
/// The celebration happens in layers:
///   BEHIND the scroll  — slowly turning golden light rays
///   AROUND the scroll  — pixel sparkles twinkling just outside the frame
///   ACROSS the screen  — pixel petals + leaves drifting down (~2.5 s)
///   IN the scroll      — the grown plant as a big trophy, its name on a
///                        ribbon, "You did it!", and a +XP badge
/// Everything arrives in a quick sequence so the eye goes: scroll → plant
/// → text → buttons.
///
/// The two buttons return `true` (start a new session right away) or
/// `false` (go home) to whoever called showDialog.
class HarvestCelebrationDialog extends StatefulWidget {
  const HarvestCelebrationDialog({
    super.key,
    this.plantAsset = 'assets/images/plant/stages/fullgrown.png',
    this.plantName = 'plant',
    this.aura,
  });

  /// The grown plant's sprite and name (sunflower, cactus, …).
  final String plantAsset;
  final String plantName;

  /// Legendary+ plants keep their living effect in the trophy.
  final PlantAura? aura;

  @override
  State<HarvestCelebrationDialog> createState() => _HarvestCelebrationDialogState();
}

class _HarvestCelebrationDialogState extends State<HarvestCelebrationDialog> with TickerProviderStateMixin {
  static const _frameAsset = 'assets/images/popups/harvest_frame.png';

  // Real size of the scroll art in pixels.
  static const double _artWidth = 144;
  static const double _artHeight = 192;

  // The open parchment area inside the scroll, as fractions of the art
  // (measured from harvest_frame.png). If you redraw the frame, re-check.
  static const double _paperTop = 0.20;
  static const double _paperBottom = 0.16;
  static const double _paperSide = 0.14;

  // Space the two buttons need under the scroll.
  static const double _buttonsHeight = AppSizes.buttonHeight * 2 + AppSpacing.md + AppSpacing.lg;

  /// One-off entrance sequence (scroll → plant → text → buttons).
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  /// Endless slow loop for the rays and twinkles.
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));

  /// One-off falling petals.
  late final AnimationController _confetti =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // "Remove animations" is on: show the finished state, no motion.
      _intro.value = 1;
      _confetti.value = 1;
    } else {
      _intro.forward();
      _confetti.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _confetti.dispose();
    super.dispose();
  }

  /// A slice of the intro timeline, eased.
  Animation<double> _step(double start, double end, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(start, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final scrollPop = _step(0.0, 0.45, Curves.elasticOut);
    final scrollFade = _step(0.0, 0.15);
    final plantPop = _step(0.2, 0.7, Curves.elasticOut);
    final textIn = _step(0.45, 0.8);
    final xpIn = _step(0.6, 0.9, Curves.elasticOut);
    final buttonsIn = _step(0.7, 1.0);

    return PopScope(
      canPop: false, // force an explicit choice instead of a back-swipe
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Falling petals across the whole screen (behind everything else).
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_confetti.value)),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final scale = min(
                        AppSizes.artScale,
                        min((constraints.maxWidth - 40) / _artWidth,
                            (constraints.maxHeight - _buttonsHeight - 20) / _artHeight),
                      );
                      final frameW = _artWidth * scale;
                      final frameH = _artHeight * scale;

                      return SizedBox(
                        width: max(frameW, 240),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: SizedBox(
                                width: frameW,
                                height: frameH,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Rays + sparkles live OUTSIDE the frame.
                                    Positioned(
                                      left: -frameW,
                                      right: -frameW,
                                      top: -frameH * 0.6,
                                      bottom: -frameH * 0.6,
                                      child: IgnorePointer(
                                        child: FadeTransition(
                                          opacity: scrollFade,
                                          child: AnimatedBuilder(
                                            animation: _loop,
                                            builder: (context, _) => CustomPaint(
                                              painter: _RaysAndSparklesPainter(
                                                spin: _loop.value,
                                                frame: Size(frameW, frameH),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: FadeTransition(
                                        opacity: scrollFade,
                                        child: ScaleTransition(
                                          scale: Tween(begin: 0.6, end: 1.0).animate(scrollPop),
                                          child: _scroll(frameW, frameH, scale, plantPop, textIn, xpIn),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            FadeTransition(
                              opacity: buttonsIn,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(buttonsIn),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    PixelButton(
                                      label: 'Start New Session',
                                      onPressed: () => Navigator.of(context).pop(true),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    PixelButton(
                                      label: 'Go Home',
                                      tone: ButtonTone.secondary,
                                      onPressed: () => Navigator.of(context).pop(false),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The scroll art with the trophy content packed into its parchment.
  Widget _scroll(
    double width,
    double height,
    double scale,
    Animation<double> plantPop,
    Animation<double> textIn,
    Animation<double> xpIn,
  ) {
    final paperW = width * (1 - _paperSide * 2);
    final paperH = height * (1 - _paperTop - _paperBottom);
    // The trophy: as wide as the parchment allows. zoom crops the empty
    // top/bottom of the 128px canvas so the plant itself fills the space.
    final plantSize = min(paperW * 0.95, paperH * 0.6);

    Widget textStep(Widget child) => FadeTransition(
          opacity: textIn,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(textIn),
            child: child,
          ),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _frameAsset,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: BoxDecoration(
              color: AppColors.parchment,
              border: Border.all(color: AppColors.panelDark, width: 3),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            width * _paperSide,
            height * _paperTop,
            width * _paperSide,
            height * _paperBottom,
          ),
          // Shrinks the block on tiny phones so nothing ever spills out.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: paperW,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: plantPop,
                    alignment: Alignment.bottomCenter,
                    child: PlantAuraEffect(
                      aura: widget.aura,
                      zoom: 1.45,
                      zoomAnchorY: 0.575,
                      child: SizedBox(
                        width: plantSize,
                        height: plantSize,
                        child: ClipRect(
                          child: Transform.scale(
                            scale: 1.45,
                            alignment: const Alignment(0, 0.15),
                            child: Image.asset(
                              widget.plantAsset,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              gaplessPlayback: true,
                              semanticLabel: 'Your fully grown ${widget.plantName}',
                              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Plant name on a dark ribbon — high contrast on parchment.
                  textStep(
                    PixelPanel(
                      style: PanelStyle.dark,
                      expand: false,
                      shadow: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Text(
                        widget.plantName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppTheme.pixelHeading(size: 9, color: AppColors.accentGold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  textStep(
                    Text(
                      'You did it!',
                      textAlign: TextAlign.center,
                      style: AppTheme.pixelHeading(size: 14, color: AppColors.greenDeep),
                    ),
                  ),
                  const SizedBox(height: 4),
                  textStep(
                    Text(
                      'Fully grown and planted in your garden.',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(size: 13, weight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ScaleTransition(
                    scale: xpIn,
                    child: PixelPanel(
                      style: PanelStyle.dark,
                      outlineColor: AppColors.accentGold,
                      expand: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: AppColors.accentGold),
                          const SizedBox(width: 5),
                          Text(
                            '+${GardenProgress.xpPerHarvest} XP',
                            style: AppTheme.pixelHeading(size: 10, color: AppColors.accentGold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Effects (all drawn in code, square "pixels" only)
// ---------------------------------------------------------------------------

/// Golden light rays turning slowly behind the scroll, plus pixel
/// sparkles that twinkle just OUTSIDE the frame edges.
class _RaysAndSparklesPainter extends CustomPainter {
  _RaysAndSparklesPainter({required this.spin, required this.frame});

  final double spin; // 0..1, loops
  final Size frame; // the scroll's size (it sits in the middle of this canvas)

  static const double px = AppSizes.artScale;

  // Sparkle spots around the frame, as fractions of the frame
  // (below 0 or above 1 = outside it). Third value = twinkle offset.
  static const _sparkles = [
    [-0.16, 0.08, 0.0],
    [1.14, 0.14, 0.35],
    [-0.2, 0.46, 0.6],
    [1.18, 0.5, 0.15],
    [-0.12, 0.86, 0.8],
    [1.12, 0.82, 0.5],
    [0.18, -0.1, 0.7],
    [0.84, -0.08, 0.25],
    [0.5, -0.16, 0.9],
    [0.1, 1.06, 0.45],
    [0.9, 1.05, 0.05],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide;

    // Rays: 12 soft wedges, alternating strength.
    final angle0 = spin * 2 * pi;
    const count = 12;
    for (var i = 0; i < count; i++) {
      final a = angle0 + i * 2 * pi / count;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + cos(a - 0.11) * radius, center.dy + sin(a - 0.11) * radius)
        ..lineTo(center.dx + cos(a + 0.11) * radius, center.dy + sin(a + 0.11) * radius)
        ..close();
      canvas.drawPath(path, Paint()..color = AppColors.accentGold.withValues(alpha: i.isEven ? 0.20 : 0.10));
    }

    // Sparkles around the frame.
    final frameRect = Rect.fromCenter(center: center, width: frame.width, height: frame.height);
    for (final s in _sparkles) {
      final t = (spin * 6 + s[2]) % 1.0; // each twinkles on its own beat
      final strength = (1 - (2 * t - 1).abs()); // 0 → 1 → 0
      if (strength < 0.15) continue;
      final p = Offset(frameRect.left + frameRect.width * s[0], frameRect.top + frameRect.height * s[1]);
      _pixelStar(canvas, p, (strength * 3).round() + 1, strength);
    }
  }

  /// A plus-shaped pixel star: white core, gold arms.
  void _pixelStar(Canvas canvas, Offset c, int arm, double alpha) {
    final gold = Paint()..color = const Color(0xFFFFE27A).withValues(alpha: alpha);
    final white = Paint()..color = Colors.white.withValues(alpha: alpha);
    final cx = (c.dx / px).round() * px, cy = (c.dy / px).round() * px;
    canvas.drawRect(Rect.fromLTWH(cx - px * arm, cy - px / 2, px * arm * 2 + px, px * 2), gold);
    canvas.drawRect(Rect.fromLTWH(cx - px / 2, cy - px * arm, px * 2, px * arm * 2 + px), gold);
    canvas.drawRect(Rect.fromLTWH(cx - px / 2, cy - px / 2, px * 2, px * 2), white);
  }

  @override
  bool shouldRepaint(_RaysAndSparklesPainter old) => old.spin != spin || old.frame != frame;
}

/// Pixel petals and leaves drifting down across the screen, once.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress);

  final double progress; // 0..1

  static const _colors = [
    AppColors.accentGold,
    Color(0xFFEFD845), // sunflower yellow
    Color(0xFFF07AA6), // cactus pink
    Color(0xFFD2BFF5), // lily lavender
    AppColors.accentGreen,
    Color(0xFF74AD50),
    Color(0xFFFFF4E0),
  ];

  // Fixed seed = the same pleasant pattern every time.
  static final _pieces = List.generate(42, (i) {
    final r = Random(i * 7919 + 13);
    return (
      x: r.nextDouble(),
      delay: r.nextDouble() * 0.35,
      speed: 0.75 + r.nextDouble() * 0.5,
      sway: 6 + r.nextDouble() * 14,
      phase: r.nextDouble() * 2 * pi,
      leaf: r.nextDouble() < 0.3,
      size: 4.0 + (r.nextInt(2) * 2),
      color: _colors[r.nextInt(_colors.length)],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    for (final p in _pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0) * p.speed;
      if (t <= 0 || t >= 1) continue;
      // Fade out over the last stretch so nothing pops off abruptly.
      final alpha = t > 0.8 ? (1 - t) / 0.2 : 1.0;
      final x = p.x * size.width + sin(t * 6 + p.phase) * p.sway;
      final y = -20 + t * (size.height + 40);
      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      // Snap to the 2dp pixel grid so pieces stay crisp squares.
      final sx = (x / 2).round() * 2.0, sy = (y / 2).round() * 2.0;
      if (p.leaf) {
        canvas.drawRect(Rect.fromLTWH(sx, sy, p.size + 2, p.size / 2), paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(sx, sy, p.size, p.size), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
