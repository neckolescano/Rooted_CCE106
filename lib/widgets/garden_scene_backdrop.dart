import 'dart:math';
import 'package:flutter/material.dart';
import '../models/garden_scenes.dart';

/// The world outside, in the equipped Garden Scene: the meadow picture
/// with the scene's colour wash, and its moving pixel effects (twinkling
/// stars, falling petals or rain, drifting fireflies…) on top.
///
/// Used behind the Timer, in the Garden Archive picture, through the Home
/// greenhouse window, and on the scene shelf.
class GardenSceneBackdrop extends StatefulWidget {
  const GardenSceneBackdrop({
    super.key,
    required this.scene,
    this.alignment = Alignment.center,
    this.pixel = 2,
    this.animate = true,
    this.filterQuality = FilterQuality.none,
  });

  final GardenScene scene;

  /// Which part of the (tall) meadow picture to show.
  final Alignment alignment;

  /// Size of one effect pixel in dp (2 full screen, smaller in thumbnails).
  final double pixel;

  /// false = a still picture (e.g. small shelf thumbnails).
  final bool animate;
  final FilterQuality filterQuality;

  static const meadowAsset = 'assets/images/backgrounds/garden_meadow.png';

  @override
  State<GardenSceneBackdrop> createState() => _GardenSceneBackdropState();
}

class _GardenSceneBackdropState extends State<GardenSceneBackdrop> with SingleTickerProviderStateMixin {
  // A slow 2-minute loop; effects read it as seconds.
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(minutes: 2));

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(GardenSceneBackdrop old) {
    super.didUpdateWidget(old);
    _syncClock();
  }

  void _syncClock() {
    final moving = widget.animate && widget.scene.effects.isNotEmpty;
    if (moving && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!moving && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget picture = Image.asset(
      GardenSceneBackdrop.meadowAsset,
      fit: BoxFit.cover,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFFAFD8C9)),
    );
    final tint = widget.scene.tint;
    if (tint != null) {
      // "modulate" multiplies the colours: keeps the pixel detail, shifts the mood.
      picture = ColorFiltered(colorFilter: ColorFilter.mode(Color(tint), BlendMode.modulate), child: picture);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        picture,
        if (widget.scene.effects.isNotEmpty)
          RepaintBoundary(
            child: CustomPaint(
              painter: SceneEffectsPainter(
                widget.scene.effects,
                clock: widget.animate ? _clock : null,
                pixel: widget.pixel,
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws a scene's effects on a pixel grid. Repaints by itself as [clock]
/// ticks (no widget rebuilds), so it stays cheap behind the Timer.
class SceneEffectsPainter extends CustomPainter {
  SceneEffectsPainter(this.effects, {this.clock, required this.pixel}) : super(repaint: clock);

  final List<SceneEffect> effects;
  final Animation<double>? clock;
  final double pixel;

  // Fixed "random" particles (same every time), as fractions of the size.
  static final _stars = _particles(46, 3);
  static final _petals = _particles(26, 5);
  static final _rain = _particles(70, 7);
  static final _flies = _particles(14, 11);
  static final _leaves = _particles(10, 13);

  static List<({double x, double y, double speed, double phase})> _particles(int n, int seed) {
    final r = Random(seed);
    return [
      for (var i = 0; i < n; i++)
        (x: r.nextDouble(), y: r.nextDouble(), speed: 0.6 + r.nextDouble() * 0.8, phase: r.nextDouble() * 2 * pi),
    ];
  }

  double _snap(double v) => (v / pixel).round() * pixel;

  Paint _paint(int argb, [double alpha = 1]) => Paint()
    ..isAntiAlias = false
    ..color = Color(argb).withValues(alpha: alpha.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final t = (clock?.value ?? 0.3) * 120; // seconds
    final w = size.width, h = size.height, p = pixel;
    for (final effect in effects) {
      switch (effect) {
        case SceneEffect.sun:
          // A low, warm sun with a soft glow ring.
          final c = Offset(w * 0.78, h * 0.3);
          final r = max(p * 6, w * 0.09);
          _disc(canvas, c, r * 1.45, _paint(0xFFFFD27A, 0.25 + 0.05 * sin(t * 0.8)), null);
          _disc(canvas, c, r, _paint(0xFFFFE08A), _paint(0xFFFFB347));
        case SceneEffect.moon:
          final c = Offset(w * 0.8, h * 0.17);
          final r = max(p * 5, w * 0.07);
          _disc(canvas, c, r * 1.5, _paint(0xFFFFF4D6, 0.12), null);
          _disc(canvas, c, r, _paint(0xFFFFF4D6), _paint(0xFFD9CFA8));
          canvas.drawRect(Rect.fromLTWH(_snap(c.dx - r * 0.3), _snap(c.dy - r * 0.2), p * 2, p * 2), _paint(0xFFE3D6AE));
          canvas.drawRect(Rect.fromLTWH(_snap(c.dx + r * 0.2), _snap(c.dy + r * 0.3), p * 2, p), _paint(0xFFE3D6AE));
        case SceneEffect.stars:
          for (final s in _stars) {
            final a = 0.35 + 0.65 * sin(t * 1.4 * s.speed + s.phase).abs();
            final x = _snap(s.x * w), y = _snap(s.y * h * 0.55);
            final paint = _paint(s.speed > 1.2 ? 0xFFFFE9A8 : 0xFFFFFBEA, a);
            canvas.drawRect(Rect.fromLTWH(x, y, p, p), paint);
            if (s.speed > 1.25 && a > 0.85) {
              // The odd star sparkles into a little cross.
              canvas.drawRect(Rect.fromLTWH(x - p, y, p * 3, p), paint);
              canvas.drawRect(Rect.fromLTWH(x, y - p, p, p * 3), paint);
            }
          }
        case SceneEffect.petals:
          for (final s in _petals) {
            final fall = (s.y + t * 0.06 * s.speed) % 1.0;
            final x = _snap((s.x * w + 30 * sin(t * 0.9 + s.phase) + t * 8 * s.speed) % (w + 20) - 10);
            final y = _snap(fall * (h + 20) - 10);
            canvas.drawRect(Rect.fromLTWH(x, y, p * 2, p), _paint(s.speed > 1 ? 0xFFF58DB3 : 0xFFFFD0E0));
            canvas.drawRect(Rect.fromLTWH(x + p, y + p, p, p), _paint(0xFFF58DB3, 0.8));
          }
        case SceneEffect.rain:
          final drop = _paint(0xFFEAF4FF, 0.7);
          final far = _paint(0xFFD6E4F0, 0.4);
          for (final s in _rain) {
            final fall = (s.y + t * 0.9 * s.speed) % 1.0;
            final x = _snap((s.x * w + fall * 18) % w);
            final y = _snap(fall * (h + 30) - 30);
            // Faster drops are nearer: longer and brighter.
            final near = s.speed > 1.0;
            canvas.drawRect(Rect.fromLTWH(x, y, near ? p * 0.75 : p / 2, near ? p * 6 : p * 4), near ? drop : far);
          }
        case SceneEffect.fireflies:
          for (final s in _flies) {
            final glow = 0.5 + 0.5 * sin(t * 2 * s.speed + s.phase);
            final x = _snap(s.x * w + 22 * sin(t * 0.5 * s.speed + s.phase));
            final y = _snap(h * (0.45 + 0.5 * s.y) + 14 * sin(t * 0.7 + s.phase * 2));
            canvas.drawRect(Rect.fromLTWH(x - p, y - p, p * 3, p * 3), _paint(0xFFD9F07A, glow * 0.3));
            canvas.drawRect(Rect.fromLTWH(x, y, p, p), _paint(0xFFE9FF9A, glow));
          }
        case SceneEffect.leaves:
          for (final s in _leaves) {
            final fall = (s.y + t * 0.04 * s.speed) % 1.0;
            final x = _snap(s.x * w + 26 * sin(t * 1.1 + s.phase));
            final y = _snap(fall * (h + 20) - 10);
            final flip = sin(t * 3 + s.phase) > 0;
            final paint = _paint(s.speed > 1 ? 0xFF7CB350 : 0xFFA8D27F);
            canvas.drawRect(Rect.fromLTWH(x, y, p * 3, p * 1.5), paint);
            canvas.drawRect(Rect.fromLTWH(x + (flip ? 0 : p * 1.5), y - p * 1.5, p * 1.5, p * 1.5), paint);
          }
      }
    }
  }

  /// A round pixel disc (sun / moon), with an optional darker rim.
  void _disc(Canvas canvas, Offset c, double r, Paint fill, Paint? rim) {
    for (var y = -r; y <= r; y += pixel) {
      final half = _snap(sqrt(max(0, r * r - y * y)));
      final paint = rim != null && y.abs() > r - pixel * 2 ? rim : fill;
      canvas.drawRect(Rect.fromLTWH(_snap(c.dx) - half, _snap(c.dy + y), half * 2, pixel), paint);
    }
  }

  @override
  bool shouldRepaint(SceneEffectsPainter old) =>
      old.effects != effects || old.pixel != pixel || old.clock != clock;
}
