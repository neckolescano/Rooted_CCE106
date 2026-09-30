import 'dart:math';
import 'package:flutter/material.dart';
import '../models/garden_scenes.dart';

/// Size of the land pictures in "art pixels" (tool/generate_meadow.dart
/// draws them at 184 × 327 and scales them up 4×).
const double _artW = 184, _artH = 327;

/// The sky is painted down to here; the hills cover everything below.
const int _skyBottom = 200;

/// The world outside in a [SceneLook], drawn in three layers:
///   1. the sky (colour bands, drifting clouds, sun, moon, stars…),
///   2. the land picture, whose sky is see-through — so the hills and the
///      tree are always in FRONT of the sun and moon,
///   3. front effects (petals, rain, fireflies, glowing windows…).
///
/// Used behind the Timer, in the Garden Archive picture, through the Home
/// greenhouse window, on the scene shelf and on Player Cards.
class GardenSceneBackdrop extends StatefulWidget {
  const GardenSceneBackdrop({
    super.key,
    this.scene,
    this.look,
    this.alignment = Alignment.center,
    this.pixel = 2,
    this.animate = true,
    this.filterQuality = FilterQuality.none,
  }) : assert(scene != null || look != null);

  /// Show this Garden Scene's look…
  final GardenScene? scene;

  /// …or this look directly (Player Cards).
  final SceneLook? look;

  /// Which part of the (tall) picture to show.
  final Alignment alignment;

  /// Size of one front-effect pixel in dp (2 full screen, smaller in thumbnails).
  final double pixel;

  /// false = a still picture (e.g. small shelf thumbnails).
  final bool animate;
  final FilterQuality filterQuality;

  static const meadowAsset = GardenScene.meadowPicture;

  @override
  State<GardenSceneBackdrop> createState() => _GardenSceneBackdropState();
}

class _GardenSceneBackdropState extends State<GardenSceneBackdrop> with SingleTickerProviderStateMixin {
  // Only a "tick" to repaint the moving layers; the effects read the real
  // time (see _seconds), so nothing jumps when the controller loops.
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(minutes: 1));

  SceneLook get _look => widget.look ?? widget.scene!.look;

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
    if (widget.animate && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!widget.animate && _clock.isAnimating) {
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
    final look = _look;
    final clock = widget.animate ? _clock : null;
    return LayoutBuilder(builder: (context, box) {
      final art = _artRect(box.biggest, widget.alignment);
      Widget land = Image.asset(
        look.land,
        fit: BoxFit.cover,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
      final tint = look.tint;
      if (tint != null) {
        // "modulate" multiplies the colours: keeps the pixel detail, shifts the mood.
        land = ColorFiltered(colorFilter: ColorFilter.mode(Color(tint), BlendMode.modulate), child: land);
      }
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: _StillSkyPainter(look, art))),
            RepaintBoundary(child: CustomPaint(painter: SkyPainter(look, art, clock: clock))),
            land,
            RepaintBoundary(
              child: CustomPaint(painter: SceneEffectsPainter(look, art, clock: clock, pixel: widget.pixel)),
            ),
          ],
        ),
      );
    });
  }
}

/// Where the whole land picture lands on screen with BoxFit.cover and
/// [alignment] — the same maths Image.asset uses, so the painted sky lines
/// up with the picture exactly.
Rect _artRect(Size size, Alignment alignment) {
  final scale = max(size.width / _artW, size.height / _artH);
  final w = _artW * scale, h = _artH * scale;
  return Rect.fromLTWH(
    (size.width - w) * (alignment.x + 1) / 2,
    (size.height - h) * (alignment.y + 1) / 2,
    w,
    h,
  );
}

/// Seconds for the moving effects: the real time (never jumps back), or a
/// fixed moment for still pictures.
double _seconds(Animation<double>? clock) =>
    clock == null ? 36 : (DateTime.now().millisecondsSinceEpoch % 3600000) / 1000;

typedef _Particle = ({double x, double y, double speed, double phase});

/// Fixed "random" particles (same every time), as fractions.
List<_Particle> _particles(int n, int seed) {
  final r = Random(seed);
  return [
    for (var i = 0; i < n; i++)
      (x: r.nextDouble(), y: r.nextDouble(), speed: 0.6 + r.nextDouble() * 0.8, phase: r.nextDouble() * 2 * pi),
  ];
}

Paint _paint(int argb, [double alpha = 1]) => Paint()
  ..isAntiAlias = false
  ..color = Color(argb).withValues(alpha: alpha.clamp(0.0, 1.0));

/// Drawing in art pixels, so everything sits on the land picture's grid.
class _Art {
  _Art(this.canvas, this.rect) : px = rect.width / _artW;

  final Canvas canvas;
  final Rect rect;
  final double px;

  void dot(double x, double y, Paint paint, [double w = 1, double h = 1]) {
    canvas.drawRect(Rect.fromLTWH(rect.left + x.floor() * px, rect.top + y.floor() * px, w * px, h * px), paint);
  }

  /// A round pixel disc. [shade] (optional) colours the lower-right part.
  void disc(double cx, double cy, double r, Paint fill, {Paint? shade, double shadeFrom = 0.35}) {
    for (var dy = -r.floor(); dy <= r.floor(); dy++) {
      final half = sqrt(max(0, r * r - dy * dy)).roundToDouble();
      if (half <= 0) continue;
      dot(cx - half, cy + dy, fill, half * 2);
      if (shade != null) {
        final from = (half * shadeFrom).roundToDouble();
        dot(cx + from, cy + dy, shade, half - from);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 1a. The still sky: colour bands (+ a rainbow). Painted once.
// ---------------------------------------------------------------------------

class _StillSkyPainter extends CustomPainter {
  _StillSkyPainter(this.look, this.rect);

  final SceneLook look;
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final a = _Art(canvas, rect);
    final bands = look.sky;
    final bandH = _skyBottom / bands.length;
    // Rows of one colour are merged; the last rows of each band are a
    // checkerboard with the next colour (a soft pixel-art blend).
    var y = 0;
    while (y < _skyBottom) {
      final band = min(bands.length - 1, (y / bandH).floor());
      final into = y / bandH - band;
      if (into > 0.75 && band < bands.length - 1) {
        a.dot(0, y.toDouble(), _paint(bands[band]), _artW);
        final next = _paint(bands[band + 1]);
        for (var x = y % 2; x < _artW; x += 2) {
          a.dot(x.toDouble(), y.toDouble(), next);
        }
        y++;
        continue;
      }
      var end = y + 1;
      while (end < _skyBottom && min(bands.length - 1, (end / bandH).floor()) == band && end / bandH - band <= 0.75) {
        end++;
      }
      a.dot(0, y.toDouble(), _paint(bands[band]), _artW, (end - y).toDouble());
      y = end;
    }
    // Paint the sky above the picture too (tall screens never show it,
    // but never leave a gap).
    if (rect.top > 0) canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rect.top), _paint(bands.first));

    if (look.effects.contains(SceneEffect.rainbow)) {
      // A soft rainbow arcing behind the hills and the tree.
      const colors = [0xFFFF6B6B, 0xFFFFA94D, 0xFFFFE066, 0xFF69DB7C, 0xFF4DABF7, 0xFF9775FA];
      const cx = 88.0, cy = 196.0;
      for (var b = 0; b < colors.length; b++) {
        final r = 92.0 - b * 3;
        final paint = _paint(colors[b], 0.45);
        for (var dx = -r; dx <= r; dx++) {
          final top = cy - sqrt(max(0, r * r - dx * dx));
          final top2 = cy - sqrt(max(0, (r - 3) * (r - 3) - dx * dx));
          a.dot(cx + dx, top, paint, 1, max(1, (top2 - top).floorToDouble()));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_StillSkyPainter old) => old.look != look || old.rect != rect;
}

// ---------------------------------------------------------------------------
// 1b. The moving sky: stars, aurora, moon, sun, clouds, birds, lightning.
// ---------------------------------------------------------------------------

class SkyPainter extends CustomPainter {
  SkyPainter(this.look, this.rect, {this.clock}) : super(repaint: clock);

  final SceneLook look;
  final Rect rect;
  final Animation<double>? clock;

  static final _stars = _particles(70, 3);

  @override
  void paint(Canvas canvas, Size size) {
    final t = _seconds(clock);
    final a = _Art(canvas, rect);
    final fx = look.effects;
    if (fx.contains(SceneEffect.stars)) _drawStars(a, t);
    if (fx.contains(SceneEffect.shootingStars)) _drawShootingStar(a, t);
    if (fx.contains(SceneEffect.aurora)) _drawAurora(a, t);
    if (fx.contains(SceneEffect.moon)) _drawMoon(a, t);
    if (fx.contains(SceneEffect.sun)) _drawSun(a, t);
    if (fx.contains(SceneEffect.sunset)) _drawSunset(a, t);
    if (look.clouds != null) _drawClouds(a, t);
    if (fx.contains(SceneEffect.birds)) _drawBirds(a, t);
    if (fx.contains(SceneEffect.lightning)) _drawLightning(a, t);
  }

  void _drawStars(_Art a, double t) {
    for (final s in _stars) {
      final alpha = 0.35 + 0.65 * sin(t * 1.4 * s.speed + s.phase).abs();
      final x = s.x * _artW, y = s.y * 150;
      final paint = _paint(s.speed > 1.2 ? 0xFFFFE9A8 : 0xFFFFFBEA, alpha);
      a.dot(x, y, paint);
      if (s.speed > 1.3 && alpha > 0.85) {
        // The odd star sparkles into a little cross.
        a.dot(x - 1, y, paint, 3);
        a.dot(x, y - 1, paint, 1, 3);
      }
    }
  }

  /// Every few seconds a star shoots across the sky.
  void _drawShootingStar(_Art a, double t) {
    const period = 7.0, life = 0.9;
    final k = (t / period).floor();
    final ph = t - k * period;
    if (ph > life) return;
    final r = Random(k);
    final sx = 10 + r.nextDouble() * 100, sy = 8 + r.nextDouble() * 50;
    final p = ph / life;
    final hx = sx + p * 56, hy = sy + p * 24;
    for (var i = 0; i < 9; i++) {
      final fade = (1 - i / 9) * (p < 0.8 ? 1 : (1 - p) / 0.2);
      a.dot(hx - i * 2.2, hy - i * 0.95, _paint(0xFFFFFBEA, fade));
    }
  }

  void _drawAurora(_Art a, double t) {
    // Two waving curtains of green and violet light, fading downward.
    for (var band = 0; band < 2; band++) {
      final baseY = 16.0 + band * 22;
      final cols = band == 0
          ? const [0xFFB8FFE0, 0xFF5CF0A8, 0xFF2FC79A, 0xFF1F8E8A]
          : const [0xFFEBC2FF, 0xFFB287FF, 0xFF7C6BFF, 0xFF4E7BE8];
      for (var x = 0.0; x < _artW; x += 2) {
        final u = x / _artW;
        final top = baseY + sin(u * 5 + t * 0.35 * (band + 1) + band * 2) * 10 + sin(u * 11 - t * 0.5) * 3;
        final len = 30 + 14 * sin(u * 7 + t * 0.6 + band);
        final shimmer = 0.65 + 0.35 * sin(u * 23 + t * 1.3 + band);
        for (var k = 0; k < 4; k++) {
          a.dot(x, top + len * k / 4, _paint(cols[k], (0.5 - k * 0.11) * shimmer), 2, len / 4 + 1);
        }
      }
    }
  }

  void _drawMoon(_Art a, double t) {
    final c = look.moonAt, r = look.moonRadius;
    final glow = 0.9 + 0.1 * sin(t * 0.7);
    a.disc(c.dx, c.dy, r * 1.9, _paint(0xFFFFF4D6, 0.06 * glow));
    a.disc(c.dx, c.dy, r * 1.4, _paint(0xFFFFF4D6, 0.12 * glow));
    a.disc(c.dx, c.dy, r, _paint(0xFFFFF4D6), shade: _paint(0xFFE9DDB6), shadeFrom: 0.4);
    // craters
    final crater = _paint(0xFFE0D2A8);
    a.dot(c.dx - r * 0.45, c.dy - r * 0.3, crater, 2, 2);
    a.dot(c.dx + r * 0.1, c.dy + r * 0.35, crater, 2, 1);
    a.dot(c.dx - r * 0.15, c.dy + r * 0.05, crater);
  }

  /// A bright day sun with a gently pulsing glow and twinkling short rays.
  void _drawSun(_Art a, double t) {
    final c = look.sunAt, r = look.sunRadius;
    final pulse = 0.85 + 0.15 * sin(t * 0.9);
    a.disc(c.dx, c.dy, r * 2.2, _paint(0xFFFFF4C0, 0.12 * pulse));
    a.disc(c.dx, c.dy, r * 1.5, _paint(0xFFFFEFA0, 0.22 * pulse));
    for (var i = 0; i < 8; i++) {
      final ang = i * pi / 4 + t * 0.05;
      final twinkle = 0.25 + 0.2 * sin(t * 1.6 + i);
      for (var k = 0; k < 4; k++) {
        final d = r + 4 + k * 2.0;
        a.dot(c.dx + cos(ang) * d, c.dy + sin(ang) * d, _paint(0xFFFFF6C8, twinkle * (1 - k / 4)));
      }
    }
    a.disc(c.dx, c.dy, r, _paint(0xFFFFE27A), shade: _paint(0xFFFFC94A), shadeFrom: 0.3);
    a.dot(c.dx - r * 0.5, c.dy - r * 0.5, _paint(0xFFFFFBE0), 2, 2);
  }

  /// Golden Sunset: a big sun sinking slowly behind the far hills, with
  /// layered glow, slowly turning rays and scrolling stripes.
  void _drawSunset(_Art a, double t) {
    final r = look.sunRadius;
    final cx = look.sunAt.dx;
    final cy = look.sunAt.dy + 3 * sin(t * 0.05); // sinks and rises over ~2 minutes
    final pulse = 0.8 + 0.2 * sin(t * 0.9);
    a.disc(cx, cy, r + 22, _paint(0xFFFF8A5E, 0.10 * pulse));
    a.disc(cx, cy, r + 13, _paint(0xFFFFB45E, 0.16 * pulse));
    a.disc(cx, cy, r + 6, _paint(0xFFFFE08A, 0.26 * pulse));
    // rays
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final ang = i * 2 * pi / rays + t * 0.04;
      final flicker = 0.7 + 0.3 * sin(t * 1.7 + i * 1.3);
      for (var k = 0; k < 11; k++) {
        final d = r + 8 + k * 3.0;
        a.dot(cx + cos(ang) * d, cy + sin(ang) * d, _paint(0xFFFFE9A8, 0.32 * (1 - k / 11) * flicker));
      }
    }
    // the disc: pale gold on top, deep orange below, with stripes drifting down
    final top = _paint(0xFFFFF1B8), mid = _paint(0xFFFFD86B), low = _paint(0xFFFFA84A);
    for (var dy = -r.floor(); dy <= r.floor(); dy++) {
      if (dy > r * 0.15 && (dy - (t * 2).floor()) % 5 == 0) continue; // a stripe gap
      final half = sqrt(max(0, r * r - dy * dy)).roundToDouble();
      a.dot(cx - half, cy + dy, dy < -r * 0.4 ? top : (dy < r * 0.2 ? mid : low), half * 2);
    }
  }

  // --- clouds ------------------------------------------------------------------

  void _drawClouds(_Art a, double t) {
    final tones = look.clouds!;
    final paints = [for (final c in tones) _paint(c)];
    final list = switch (look.cloudStyle) {
      CloudStyle.puffy => _puffyPlan,
      CloudStyle.streaks => _streakPlan,
      CloudStyle.storm => _stormPlan,
    };
    for (final c in list) {
      final shape = c.shape;
      // Drift right and wrap round (off the left edge again).
      final span = _artW + shape.width + 20;
      final x = ((c.x + t * c.speed) % span) - shape.width - 10;
      final y = c.y - shape.height;
      for (final run in shape.runs) {
        a.dot(x.floorToDouble() + run.x, y + run.y, paints[run.tone], run.len.toDouble());
      }
    }
  }

  static final _big = _CloudShape.puffy(78, 20, 1);
  static final _mid = _CloudShape.puffy(96, 17, 2);
  static final _small = _CloudShape.puffy(40, 11, 3);
  static final _tiny = _CloudShape.puffy(34, 8, 4);

  static final _puffyPlan = [
    (shape: _big, x: 9.0, y: 78.0, speed: 0.5),
    (shape: _mid, x: 110.0, y: 140.0, speed: 0.3),
    (shape: _small, x: 150.0, y: 44.0, speed: 0.7),
    (shape: _tiny, x: 20.0, y: 24.0, speed: 0.4),
  ];
  static final _stormPlan = [
    (shape: _big, x: 0.0, y: 40.0, speed: 2.0),
    (shape: _mid, x: 90.0, y: 70.0, speed: 1.6),
    (shape: _big, x: 180.0, y: 100.0, speed: 1.8),
    (shape: _mid, x: 40.0, y: 130.0, speed: 1.3),
    (shape: _small, x: 140.0, y: 26.0, speed: 2.4),
    (shape: _small, x: 60.0, y: 158.0, speed: 1.1),
  ];
  static final _streakPlan = [
    (shape: _CloudShape.streak(50, 1), x: 10.0, y: 58.0, speed: 0.4),
    (shape: _CloudShape.streak(64, 2), x: 100.0, y: 86.0, speed: 0.3),
    (shape: _CloudShape.streak(40, 3), x: 40.0, y: 112.0, speed: 0.5),
    (shape: _CloudShape.streak(58, 4), x: 150.0, y: 132.0, speed: 0.35),
    (shape: _CloudShape.streak(72, 5), x: 0.0, y: 152.0, speed: 0.25),
    (shape: _CloudShape.streak(36, 6), x: 80.0, y: 36.0, speed: 0.45),
  ];

  // --- birds ---------------------------------------------------------------------

  void _drawBirds(_Art a, double t) {
    final paint = _paint(look.birdColor);
    // Two small flocks crossing now and then, flapping as they go.
    for (final f in const [(period: 46.0, y: 72.0, size: 5, offset: 0.0), (period: 63.0, y: 104.0, size: 3, offset: 25.0)]) {
      final p = ((t + f.offset) % f.period) / f.period;
      final lead = -20 + p * (_artW + 50);
      final baseY = f.y + 4 * sin(t * 0.3 + f.offset);
      for (var i = 0; i < f.size; i++) {
        final row = (i + 1) ~/ 2, side = i.isOdd ? -1 : 1;
        final bx = lead - row * 5, by = baseY + side * row * 3;
        final up = ((t * 4 + i * 0.7).floor()).isEven;
        a.dot(bx, by, paint); // body
        a.dot(bx - 1, by + (up ? -1 : 0), paint);
        a.dot(bx + 1, by + (up ? -1 : 0), paint);
      }
    }
  }

  /// Rainy Day: now and then the sky flashes with far-off lightning.
  void _drawLightning(_Art a, double t) {
    final ph = t % 11;
    final flash = ph < 0.08 ? 0.45 : (ph > 0.16 && ph < 0.4 ? 0.38 * (1 - (ph - 0.16) / 0.24) : 0.0);
    if (flash <= 0) return;
    a.dot(0, 0, _paint(0xFFF4F8FF, flash), _artW, _skyBottom.toDouble());
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.look != look || old.rect != rect || old.clock != clock;
}

/// A cloud as rows of same-colour runs (tone 0 light, 1 mid, 2 shade),
/// worked out once.
class _CloudShape {
  _CloudShape(this.width, this.height, this.runs);

  final int width, height;
  final List<({int x, int y, int len, int tone})> runs;

  /// A fluffy cumulus (the same recipe as tool/generate_meadow.dart): a row
  /// of round puffs, tallest in the middle, with a flat base, a lit top-left
  /// and a shaded underside.
  factory _CloudShape.puffy(double width, double height, int seed) {
    final r = Random(seed);
    final gw = (width + height * 2).ceil(), gh = (height * 2.2).ceil();
    final grid = List<int>.filled(gw * gh, -1);
    final baseY = gh - 1.0, cx = gw / 2;
    const n = 7;
    final puffs = <List<double>>[];
    for (var i = 0; i < n; i++) {
      final f = i / (n - 1);
      final rad = height * (0.45 + 0.55 * sin(pi * f)) * (0.85 + r.nextDouble() * 0.3);
      puffs.add([cx - width / 2 + f * width, baseY - rad * 0.55, rad]);
    }
    for (var i = 1; i < n - 1; i += 2) {
      final pf = puffs[i];
      puffs.add([pf[0] + (r.nextDouble() - 0.5) * 6, pf[1] - pf[2] * 0.55, pf[2] * 0.7]);
    }
    for (final pf in puffs) {
      for (var y = (pf[1] - pf[2]).floor(); y <= (pf[1] + pf[2]).ceil(); y++) {
        for (var x = (pf[0] - pf[2]).floor(); x <= (pf[0] + pf[2]).ceil(); x++) {
          final dx = x + 0.5 - pf[0], dy = y + 0.5 - pf[1];
          if (dx * dx + dy * dy > pf[2] * pf[2] || y > baseY || x < 0 || y < 0 || x >= gw || y >= gh) continue;
          final fromTop = (y - (pf[1] - pf[2])) / (2 * pf[2]);
          final leftness = (x - pf[0]) / pf[2];
          grid[y * gw + x] = y > baseY - height * 0.22 ? 2 : (fromTop < 0.45 && leftness < 0.35 ? 0 : 1);
        }
      }
    }
    return _CloudShape(gw, gh, _runsOf(grid, gw, gh));
  }

  /// A long thin evening cloud: a lit top, a body and a shaded base.
  factory _CloudShape.streak(int len, int seed) {
    final r = Random(seed);
    const gh = 4;
    final grid = List<int>.filled(len * gh, -1);
    void row(int y, int from, int to, int tone) {
      for (var x = max(0, from); x < min(len, to); x++) {
        grid[y * len + x] = tone;
      }
    }

    final bump = 6 + r.nextInt(max(1, len ~/ 3));
    row(0, bump, bump + len ~/ 3, 0);
    row(1, 3, len - 5, 0);
    row(2, 0, len, 1);
    row(3, 4, len - 3, 2);
    return _CloudShape(len, gh, _runsOf(grid, len, gh));
  }

  static List<({int x, int y, int len, int tone})> _runsOf(List<int> grid, int gw, int gh) {
    final runs = <({int x, int y, int len, int tone})>[];
    for (var y = 0; y < gh; y++) {
      var x = 0;
      while (x < gw) {
        final tone = grid[y * gw + x];
        if (tone < 0) {
          x++;
          continue;
        }
        var end = x + 1;
        while (end < gw && grid[y * gw + end] == tone) {
          end++;
        }
        runs.add((x: x, y: y, len: end - x, tone: tone));
        x = end;
      }
    }
    return runs;
  }
}

// ---------------------------------------------------------------------------
// 3. Front effects: particles in screen space (petals, rain…) and a few
//    things pinned to the land picture (glowing windows, owl eyes).
// ---------------------------------------------------------------------------

/// Where the lit windows are in each land picture (art pixels).
const _windows = <String, List<Rect>>{
  SceneLooks.meadowLand: [Rect.fromLTWH(29, 173, 2, 2), Rect.fromLTWH(37, 173, 2, 2)],
  SceneLooks.autumnLand: [Rect.fromLTWH(29, 173, 2, 2), Rect.fromLTWH(37, 173, 2, 2)],
  SceneLooks.winterLand: [Rect.fromLTWH(29, 173, 2, 2), Rect.fromLTWH(37, 173, 2, 2)],
  SceneLooks.sakuraLand: [Rect.fromLTWH(29, 174, 4, 4), Rect.fromLTWH(36, 174, 4, 4)],
  SceneLooks.desertLand: [
    Rect.fromLTWH(28, 174, 2, 2),
    Rect.fromLTWH(37, 174, 2, 2),
    Rect.fromLTWH(30, 166, 2, 2),
  ],
};

class SceneEffectsPainter extends CustomPainter {
  SceneEffectsPainter(this.look, this.rect, {this.clock, required this.pixel}) : super(repaint: clock);

  final SceneLook look;
  final Rect rect;
  final Animation<double>? clock;
  final double pixel;

  static final _petals = _particles(26, 5);
  static final _rain = _particles(70, 7);
  static final _flies = _particles(14, 11);
  static final _leaves = _particles(10, 13);
  static final _snow = _particles(70, 17);
  static final _autumn = _particles(22, 19);
  static final _lanterns = _particles(12, 23);
  static final _motes = _particles(34, 29);
  static final _sparkles = _particles(9, 37);
  static final _dust = _particles(40, 41);

  double _snap(double v) => (v / pixel).round() * pixel;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _seconds(clock);
    final w = size.width, h = size.height, p = pixel;
    final a = _Art(canvas, rect);
    for (final effect in look.effects) {
      switch (effect) {
        case SceneEffect.sun ||
              SceneEffect.sunset ||
              SceneEffect.moon ||
              SceneEffect.stars ||
              SceneEffect.shootingStars ||
              SceneEffect.aurora ||
              SceneEffect.rainbow ||
              SceneEffect.birds ||
              SceneEffect.lightning:
          break; // drawn in the sky, behind the land
        case SceneEffect.windowGlow:
          final flicker = 0.85 + 0.15 * sin(t * 3.1);
          for (final win in _windows[look.land] ?? const <Rect>[]) {
            a.dot(win.left - 2, win.top - 2, _paint(0xFFFFC857, 0.22 * flicker), win.width + 4, win.height + 4);
            a.dot(win.left, win.top, _paint(0xFFFFE08A), win.width, win.height);
          }
        case SceneEffect.pondShimmer:
          // Sunlight glinting on the pond.
          for (final (i, g) in const [(0, (5.0, 215.0, 4.0)), (1, (13.0, 218.0, 5.0)), (2, (20.0, 216.0, 3.0))]) {
            final glint = 0.35 + 0.65 * sin(t * 1.8 + i * 2.1).abs();
            a.dot(g.$1, g.$2, _paint(0xFFFFD08A, glint), g.$3);
          }
        case SceneEffect.owlEyes:
          // Pairs of glowing owl eyes watching from the tree and bushes,
          // each blinking now and then.
          const spots = [(148.0, 66.0), (168.0, 100.0), (156.0, 124.0), (16.0, 232.0), (160.0, 229.0)];
          for (var i = 0; i < spots.length; i++) {
            final (x, y) = spots[i];
            final blink = sin(t * (0.7 + i * 0.13) + i * 2.1) > 0.94;
            a.dot(x - 2, y - 2, _paint(0xFFFFE066, 0.16 + 0.06 * sin(t * 1.5 + i)), 9, 6);
            for (final dx in const [0.0, 3.0]) {
              if (blink) {
                a.dot(x + dx, y + 1, _paint(0xFFFFE066), 2);
              } else {
                a.dot(x + dx, y, _paint(0xFFFFE066), 2, 2);
                a.dot(x + dx + 1, y + 1, _paint(0xFF2A1A10));
              }
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
        case SceneEffect.snow:
          for (final s in _snow) {
            final fall = (s.y + t * 0.05 * s.speed) % 1.0;
            final x = _snap((s.x * w + 16 * sin(t * 0.7 * s.speed + s.phase)) % w);
            final y = _snap(fall * (h + 10) - 5);
            final size = s.speed > 1.1 ? p * 2 : p;
            canvas.drawRect(Rect.fromLTWH(x, y, size, size), _paint(0xFFFFFFFF, s.speed > 1.1 ? 0.95 : 0.7));
          }
        case SceneEffect.autumnLeaves:
          const colors = [0xFFE8702A, 0xFFB5402A, 0xFFF2C14E, 0xFFD9582A];
          for (var i = 0; i < _autumn.length; i++) {
            final s = _autumn[i];
            final fall = (s.y + t * 0.035 * s.speed) % 1.0;
            final x = _snap((s.x * w + 30 * sin(t * 0.9 + s.phase) + t * 4 * s.speed) % (w + 20) - 10);
            final y = _snap(fall * (h + 20) - 10);
            final flip = sin(t * 2.4 + s.phase) > 0;
            final paint = _paint(colors[i % colors.length]);
            canvas.drawRect(Rect.fromLTWH(x, y, p * 3, p * 1.5), paint);
            canvas.drawRect(Rect.fromLTWH(x + (flip ? 0 : p * 1.5), y - p * 1.5, p * 1.5, p * 1.5), paint);
            canvas.drawRect(Rect.fromLTWH(x + p, y + p * 1.5, p * 0.75, p), _paint(0xFF6B3A1A));
          }
        case SceneEffect.lanterns:
          // Paper lanterns drifting up into the dusk sky.
          for (final s in _lanterns) {
            final rise = (s.y + t * 0.012 * s.speed) % 1.0;
            final x = _snap(s.x * w + 10 * sin(t * 0.4 * s.speed + s.phase));
            final y = _snap(h * (0.85 - rise * 0.85));
            final near = s.speed > 1.0;
            final lw = near ? p * 4 : p * 3, lh = near ? p * 5 : p * 4;
            final fade = rise > 0.8 ? (1 - rise) / 0.2 : 1.0;
            final flicker = 0.85 + 0.15 * sin(t * 5 * s.speed + s.phase);
            canvas.drawRect(
                Rect.fromLTWH(x - lw * 0.5, y - lh * 0.4, lw * 2, lh * 1.8), _paint(0xFFFFB347, 0.18 * fade * flicker));
            canvas.drawRect(Rect.fromLTWH(x, y, lw, lh), _paint(0xFFE8583A, fade));
            canvas.drawRect(Rect.fromLTWH(x + p * 0.5, y + p, lw - p, lh - p * 2), _paint(0xFFFFC857, fade * flicker));
            canvas.drawRect(Rect.fromLTWH(x, y - p * 0.5, lw, p * 0.5), _paint(0xFF5A2A1A, fade));
            canvas.drawRect(Rect.fromLTWH(x, y + lh, lw, p * 0.5), _paint(0xFF5A2A1A, fade));
          }
        case SceneEffect.goldenMotes:
          // Warm specks of evening light floating up over the fields.
          for (final s in _motes) {
            final rise = (s.y + t * 0.02 * s.speed) % 1.0;
            final x = _snap(s.x * w + 12 * sin(t * 0.6 * s.speed + s.phase));
            final y = _snap(h * (1 - rise * 0.6));
            final glow = (0.4 + 0.6 * sin(t * 2 * s.speed + s.phase).abs()) * (rise > 0.85 ? (1 - rise) / 0.15 : 1);
            canvas.drawRect(Rect.fromLTWH(x - p, y - p, p * 3, p * 3), _paint(0xFFFFD27A, glow * 0.25));
            canvas.drawRect(Rect.fromLTWH(x, y, p, p), _paint(0xFFFFF0B0, glow));
          }
        case SceneEffect.sparkles:
          for (final s in _sparkles) {
            final alpha = sin(t * 1.5 * s.speed + s.phase);
            if (alpha < 0.2) continue;
            final x = _snap(s.x * w), y = _snap(s.y * h * 0.7);
            final gold = _paint(0xFFFFE27A, alpha);
            canvas.drawRect(Rect.fromLTWH(x - p * 2, y, p * 5, p), gold);
            canvas.drawRect(Rect.fromLTWH(x, y - p * 2, p, p * 5), gold);
            canvas.drawRect(Rect.fromLTWH(x, y, p, p), _paint(0xFFFFFFFF, alpha));
          }
        case SceneEffect.dust:
          // Sand blowing low across the desert.
          for (final s in _dust) {
            final x = _snap((s.x * w + t * 40 * s.speed) % (w + 20) - 10);
            final y = _snap(h * (0.55 + 0.45 * s.y) + 3 * sin(t * 2 + s.phase));
            canvas.drawRect(Rect.fromLTWH(x, y, p * 1.5, p * 0.75), _paint(0xFFF2D6A0, 0.55));
          }
      }
    }
  }

  @override
  bool shouldRepaint(SceneEffectsPainter old) =>
      old.look != look || old.rect != rect || old.pixel != pixel || old.clock != clock;
}
