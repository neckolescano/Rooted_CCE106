import 'dart:math';
import 'package:flutter/material.dart';
import '../models/plant_catalog.dart';

/// The living "wow" effect around the top-tier plants:
///   * embers   (Phoenix Bloom)   a warm pulsing glow + embers rising
///   * prism    (Crystal Lotus)   crystals orbiting the flower, going
///                                behind and in front of it, changing colour
///   * radiance (Golden Glory Tree) turning golden rays + rising motes
///
/// Wraps the plant sprite: effects are drawn behind AND in front of it.
/// [strength] (0..1) grows with the plant; 0 or a null [aura] = just the
/// child. Honours "Remove animations" (shows a still frame).
class PlantAuraEffect extends StatefulWidget {
  const PlantAuraEffect({
    super.key,
    required this.aura,
    required this.child,
    this.strength = 1,
    this.zoom = 1,
    this.zoomAnchorY = 0.56,
  });

  final PlantAura? aura;
  final Widget child;
  final double strength;

  /// When the sprite is shown cropped/zoomed (PixelSprite zoom), pass the
  /// same zoom and anchor so the effects line up with the plant.
  final double zoom;
  final double zoomAnchorY;

  /// How strong the effect is at each growth stage (seed … full grown).
  static double strengthForStage(int stageIndex, {bool wilted = false}) =>
      wilted ? 0 : (stageIndex / 4).clamp(0.0, 1.0);

  @override
  State<PlantAuraEffect> createState() => _PlantAuraEffectState();
}

class _PlantAuraEffectState extends State<PlantAuraEffect> with SingleTickerProviderStateMixin {
  // Every motion below repeats a whole number of times per loop, so the
  // loop is seamless.
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 8));

  bool get _active => widget.aura != null && widget.strength > 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PlantAuraEffect old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_active && !still) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
      if (still) _clock.value = 0.3;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    AuraPainter painter(bool front) => AuraPainter(
          widget.aura!,
          clock: _clock,
          strength: widget.strength,
          front: front,
          zoom: widget.zoom,
          anchorY: widget.zoomAnchorY,
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: painter(false))))),
        widget.child,
        Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: painter(true))))),
      ],
    );
  }
}

/// Draws one layer (behind or in front of the plant) of an aura, on a
/// pixel grid so it matches the art.
class AuraPainter extends CustomPainter {
  AuraPainter(
    this.aura, {
    required this.clock,
    required this.strength,
    required this.front,
    this.zoom = 1,
    this.anchorY = 0.56,
  }) : super(repaint: clock);

  final PlantAura aura;
  final Animation<double> clock;
  final double strength;
  final bool front;
  final double zoom;
  final double anchorY;

  // Fixed "random" particles, as fractions.
  static final _embers = _particles(24, 21);
  static final _sparks = _particles(12, 22);
  static final _motes = _particles(16, 23);

  static List<({double x, double y, int speed, double phase})> _particles(int n, int seed) {
    final r = Random(seed);
    return [
      for (var i = 0; i < n; i++)
        (x: r.nextDouble(), y: r.nextDouble(), speed: 1 + r.nextInt(2), phase: r.nextDouble() * 2 * pi),
    ];
  }

  late double _w, _h, _p;

  /// A point on the 128px plant canvas (as fractions), after the zoom.
  Offset _at(double fx, double fy) => Offset(_w * (0.5 + (fx - 0.5) * zoom), _h * (anchorY + (fy - anchorY) * zoom));

  double _snap(double v) => (v / _p).round() * _p;

  Paint _paint(int argb, double alpha) => Paint()
    ..isAntiAlias = false
    ..color = Color(argb).withValues(alpha: (alpha * strength).clamp(0.0, 1.0));

  void _px(Canvas canvas, Offset o, double size, Paint paint) =>
      canvas.drawRect(Rect.fromLTWH(_snap(o.dx), _snap(o.dy), size, size), paint);

  /// A soft round glow (the only non-pixel shape: light isn't pixels).
  void _glow(Canvas canvas, Offset c, double r, int argb, double alpha) {
    final color = Color(argb);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: (alpha * strength).clamp(0.0, 1.0)),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  /// A plus-shaped twinkle.
  void _star(Canvas canvas, Offset c, int arm, Paint paint) {
    final x = _snap(c.dx), y = _snap(c.dy);
    canvas.drawRect(Rect.fromLTWH(x - _p * arm, y, _p * (arm * 2 + 1), _p), paint);
    canvas.drawRect(Rect.fromLTWH(x, y - _p * arm, _p, _p * (arm * 2 + 1)), paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _w = size.width;
    _h = size.height;
    _p = max(1.0, (_w * zoom / 64).roundToDouble());
    final v = clock.value; // 0..1 over the 8 s loop
    final turn = v * 2 * pi;
    switch (aura) {
      case PlantAura.embers:
        _embersLayer(canvas, v, turn);
      case PlantAura.prism:
        _prismLayer(canvas, v, turn);
      case PlantAura.radiance:
        _radianceLayer(canvas, v, turn);
      case PlantAura.aurora:
        _auroraLayer(canvas, v, turn);
      case PlantAura.storm:
        _stormLayer(canvas, v, turn);
      case PlantAura.starfall:
        _starfallLayer(canvas, v, turn);
      case PlantAura.dragon:
        _dragonLayer(canvas, v, turn);
      case PlantAura.rainbow:
        _rainbowLayer(canvas, v, turn);
      case PlantAura.moonlight:
        _moonlightLayer(canvas, v, turn);
    }
  }

  // ------------------------------------------------------------ Owlbloom (secret)
  void _moonlightLayer(Canvas canvas, double v, double turn) {
    if (!front) {
      // A soft full moon rising behind kuwago's flower.
      _glow(canvas, _at(0.5, 0.3), _w * 0.5 * zoom, 0xFFFFF4D6, 0.4 + 0.06 * sin(turn * 2));
      _glow(canvas, _at(0.5, 0.3), _w * 0.2 * zoom, 0xFFFFFFFF, 0.3);
      for (final s in _sparks) {
        final tw = pow(max(0.0, sin(turn * s.speed * 2 + s.phase)), 3).toDouble();
        if (tw < 0.1) continue;
        _star(canvas, _at(0.1 + s.x * 0.8, 0.02 + s.y * 0.4), tw > 0.7 ? 1 : 0, _paint(0xFFFFF4D6, tw));
      }
      return;
    }
    // Little owl feathers drifting down, rocking from side to side.
    for (var i = 0; i < _motes.length; i++) {
      final m = _motes[i];
      final u = (m.y + v * m.speed) % 1.0;
      final c = _at(0.12 + m.x * 0.76 + 0.06 * sin(turn * 2 + m.phase), 0.05 + u * 0.68);
      final alpha = u < 0.1 ? u / 0.1 : (u > 0.85 ? (1 - u) / 0.15 : 1.0);
      final tilt = sin(turn * 3 + m.phase) > 0;
      final x = _snap(c.dx), y = _snap(c.dy);
      final light = _paint(i.isEven ? 0xFFF3E3C3 : 0xFFD9B98A, alpha);
      final dark = _paint(0xFF8A6440, alpha);
      canvas.drawRect(Rect.fromLTWH(x, y, _p * 3, _p), light);
      canvas.drawRect(Rect.fromLTWH(tilt ? x + _p * 3 : x - _p, y + _p, _p, _p), dark); // quill
    }
  }

  // ------------------------------------------------------------ Aurora Bell
  void _auroraLayer(Canvas canvas, double v, double turn) {
    if (!front) {
      _glow(canvas, _at(0.5, 0.42), _w * 0.42 * zoom, 0xFF5CF0A8, 0.28 + 0.08 * sin(turn * 2));
      // Two waving curtains of light behind the plant.
      final cw = _p * 2;
      for (var band = 0; band < 2; band++) {
        final cols = band == 0
            ? const [0xFFB8FFE0, 0xFF5CF0A8, 0xFF2FC79A, 0xFF1F8E8A]
            : const [0xFFEBC2FF, 0xFFB287FF, 0xFF7C6BFF, 0xFF4E7BE8];
        final x0 = _at(0.06, 0).dx, x1 = _at(0.94, 0).dx;
        for (var x = x0; x < x1; x += cw) {
          final u = (x - x0) / (x1 - x0);
          final edge = sin(pi * u); // fade out at the sides
          final fy = 0.1 + band * 0.07 + 0.05 * sin(u * 6 + turn * (band + 1)) + 0.02 * sin(u * 13 - turn * 2);
          final top = _at(0, fy).dy, len = _h * zoom * 0.26;
          for (var k = 0; k < 4; k++) {
            canvas.drawRect(Rect.fromLTWH(_snap(x), _snap(top + len * k / 4), cw, _snap(len / 4) + _p),
                _paint(cols[k], (0.42 - k * 0.09) * edge * (0.7 + 0.3 * sin(u * 20 + turn * 3))));
          }
        }
      }
      return;
    }
    for (final m in _motes) {
      final u = (m.y + v * m.speed) % 1.0;
      final c = _at(0.15 + m.x * 0.7 + 0.03 * sin(turn * 2 + m.phase), 0.05 + u * 0.6);
      final alpha = u < 0.15 ? u / 0.15 : 1 - u;
      _px(canvas, c, _p, _paint(m.speed == 1 ? 0xFFFFFFFF : 0xFFB8FFE0, alpha));
    }
  }

  // ------------------------------------------------------------ Storm Orchid
  // Two lightning strikes per loop, with a flash behind the plant.
  static const _strikes = [(at: 0.1, fx: 0.3), (at: 0.6, fx: 0.72)];

  double _strikeFlash(double v) {
    for (final s in _strikes) {
      final d = v - s.at;
      if (d >= 0 && d < 0.05) return 1 - d / 0.05;
    }
    return 0;
  }

  void _stormLayer(Canvas canvas, double v, double turn) {
    final flash = _strikeFlash(v);
    if (!front) {
      _glow(canvas, _at(0.5, 0.4), _w * 0.46 * zoom, 0xFF6B4FC8, 0.4 + 0.08 * sin(turn * 3));
      if (flash > 0) _glow(canvas, _at(0.5, 0.3), _w * 0.6 * zoom, 0xFFCFF7FF, 0.55 * flash);
      return;
    }
    for (final s in _strikes) {
      final d = v - s.at;
      if (d < 0 || d >= 0.05) continue;
      final alpha = 1 - d / 0.05;
      final pts = <Offset>[];
      var fx = s.fx;
      for (var i = 0; i <= 7; i++) {
        pts.add(_at(fx, -0.04 + i * 0.055));
        fx += (i.isEven ? 0.05 : -0.04) * (s.fx < 0.5 ? 1 : -1);
      }
      for (var i = 0; i < pts.length - 1; i++) {
        final glow = Paint()
          ..color = const Color(0xFF7FE8FF).withValues(alpha: (0.6 * alpha * strength).clamp(0.0, 1.0))
          ..strokeWidth = _p * 3
          ..isAntiAlias = false;
        final core = Paint()
          ..color = Colors.white.withValues(alpha: (alpha * strength).clamp(0.0, 1.0))
          ..strokeWidth = _p
          ..isAntiAlias = false;
        canvas.drawLine(pts[i], pts[i + 1], glow);
        canvas.drawLine(pts[i], pts[i + 1], core);
      }
    }
    // Static sparks circling the flowers.
    for (var i = 0; i < 8; i++) {
      final a = turn + i * pi / 4;
      final c = _at(0.5 + 0.3 * cos(a), 0.4 + 0.12 * sin(a));
      final f = max(0.0, sin(turn * 8 + i * 1.7));
      if (f < 0.2) continue;
      _star(canvas, c, f > 0.8 ? 1 : 0, _paint(0xFF7FE8FF, f));
    }
  }

  // ------------------------------------------------------------ Starfall Willow
  static const _constellation = [
    (0.18, 0.12), (0.3, 0.06), (0.44, 0.1), (0.58, 0.04), (0.72, 0.09), (0.84, 0.16),
  ];

  void _starfallLayer(Canvas canvas, double v, double turn) {
    if (!front) {
      _glow(canvas, _at(0.5, 0.35), _w * 0.45 * zoom, 0xFFC9DEF5, 0.35 + 0.08 * sin(turn * 2));
      final line = Paint()
        ..color = const Color(0xFFFFF4C2).withValues(alpha: (0.35 * strength).clamp(0.0, 1.0))
        ..strokeWidth = max(1.0, _p / 2)
        ..isAntiAlias = false;
      for (var i = 0; i < _constellation.length - 1; i++) {
        final a = _constellation[i], b = _constellation[i + 1];
        canvas.drawLine(_at(a.$1, a.$2), _at(b.$1, b.$2), line);
      }
      for (var i = 0; i < _constellation.length; i++) {
        final s = _constellation[i];
        final tw = 0.55 + 0.45 * sin(turn * 3 + i * 1.3).abs();
        _star(canvas, _at(s.$1, s.$2), tw > 0.85 ? 1 : 0, _paint(0xFFFFF4C2, tw));
      }
      return;
    }
    // Three shooting stars crossing the sky, each once per loop.
    for (var k = 0; k < 3; k++) {
      final u = (k / 3 + v) % 1.0;
      if (u > 0.35) continue;
      final t = u / 0.35;
      final fx0 = 0.08 + k * 0.28, fy0 = -0.04;
      for (var j = 0; j < 7; j++) {
        final tj = t - j * 0.035;
        if (tj < 0) break;
        final c = _at(fx0 + tj * 0.38, fy0 + tj * 0.42);
        final alpha = (1 - j / 7) * (t > 0.85 ? (1 - t) / 0.15 : 1);
        _px(canvas, c, j == 0 ? _p * 2 : _p, _paint(j == 0 ? 0xFFFFFFFF : 0xFFFFE27A, alpha));
      }
    }
  }

  // ------------------------------------------------------------ Dragonheart Rose
  static const _runes = [
    [0x5, 0x2, 0x5], [0x7, 0x5, 0x7], [0x2, 0x7, 0x2], [0x6, 0x3, 0x6], // 3x3 glyph bit rows
  ];

  void _dragonLayer(Canvas canvas, double v, double turn) {
    if (!front) {
      _glow(canvas, _at(0.5, 0.38), _w * 0.46 * zoom, 0xFFB02838, 0.42 + 0.1 * sin(turn * 4));
      _glow(canvas, _at(0.5, 0.36), _w * 0.16 * zoom, 0xFFFFB347, 0.35);
    }
    // A ring of glowing runes turning around the rose; the back half is
    // drawn behind the plant and the front half in front of it.
    for (var i = 0; i < 12; i++) {
      final a = turn / 12 + i * pi / 6;
      final depth = sin(a);
      if ((depth >= 0) != front) continue;
      final c = _at(0.5 + 0.4 * cos(a), 0.46 + 0.12 * depth);
      final paint = _paint(0xFFFF6A3A, depth < 0 ? 0.45 : 0.85);
      final glyph = _runes[i % _runes.length];
      final x0 = _snap(c.dx) - _p, y0 = _snap(c.dy) - _p;
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          if ((glyph[row] >> (2 - col)) & 1 == 1) {
            canvas.drawRect(Rect.fromLTWH(x0 + col * _p, y0 + row * _p, _p, _p), paint);
          }
        }
      }
    }
    if (!front) return;
    // Embers spiralling up around the stem.
    for (final e in _embers) {
      final u = (e.y + v * e.speed) % 1.0;
      final a = u * 4 * pi + e.phase;
      final c = _at(0.5 + cos(a) * 0.26 * (1 - u * 0.5), 0.72 - u * 0.7);
      final alpha = u < 0.1 ? u / 0.1 : 1 - u;
      _px(canvas, c, u < 0.4 ? _p * 2 : _p, _paint(u < 0.5 ? 0xFFFFB347 : 0xFFE0413A, alpha));
    }
  }

  // ------------------------------------------------------------ Eternal Sakura
  void _rainbowLayer(Canvas canvas, double v, double turn) {
    if (!front) {
      _glow(canvas, _at(0.5, 0.3), _w * 0.46 * zoom, 0xFFFFD6E8, 0.4);
      // Three rainbow rings pulsing outward from the crown.
      for (var k = 0; k < 3; k++) {
        final r = (k / 3 + v) % 1.0;
        final radius = _w * zoom * (0.08 + 0.46 * r);
        final color = HSVColor.fromAHSV(1, (k * 120 + v * 360) % 360, 0.45, 1).toColor();
        final paint = _paint(color.toARGB32(), (1 - r) * 0.6);
        final centre = _at(0.5, 0.3);
        final steps = max(24, (2 * pi * radius / (_p * 2)).round());
        for (var i = 0; i < steps; i++) {
          final a = i * 2 * pi / steps;
          _px(canvas, Offset(centre.dx + cos(a) * radius, centre.dy + sin(a) * radius * 0.8), _p, paint);
        }
      }
      return;
    }
    // Pastel petals drifting down and twinkles in every colour.
    const petals = [0xFFFFC2DA, 0xFFFFD2A8, 0xFFFFF1A0, 0xFFB8F0D2, 0xFFB8DEFF, 0xFFD2BFF5];
    for (var i = 0; i < _motes.length; i++) {
      final m = _motes[i];
      final u = (m.y + v * m.speed) % 1.0;
      final c = _at(0.1 + m.x * 0.8 + 0.05 * sin(turn * 2 + m.phase), 0.02 + u * 0.72);
      final alpha = u < 0.1 ? u / 0.1 : (u > 0.85 ? (1 - u) / 0.15 : 1.0);
      final paint = _paint(petals[i % petals.length], alpha);
      canvas.drawRect(Rect.fromLTWH(_snap(c.dx), _snap(c.dy), _p * 2, _p), paint);
    }
    for (final s in _sparks) {
      final tw = pow(max(0.0, sin(turn * s.speed * 2 + s.phase)), 3).toDouble();
      if (tw < 0.1) continue;
      final color = HSVColor.fromAHSV(1, (s.x * 360 + v * 360) % 360, 0.35, 1).toColor();
      _star(canvas, _at(0.12 + s.x * 0.76, 0.04 + s.y * 0.5), tw > 0.7 ? 2 : 1, _paint(color.toARGB32(), tw));
    }
  }

  void _embersLayer(Canvas canvas, double v, double turn) {
    if (!front) {
      final pulse = 0.8 + 0.2 * sin(turn * 4);
      _glow(canvas, _at(0.5, 0.38), _w * 0.46 * zoom, 0xFFFF8A2A, 0.42 * pulse);
      _glow(canvas, _at(0.5, 0.38), _w * 0.2 * zoom, 0xFFFFE08A, 0.35 * pulse);
      return;
    }
    for (final e in _embers) {
      final u = (e.y + v * e.speed) % 1.0; // 0 = just born … 1 = burnt out
      final fy = 0.62 - u * 0.62;
      final fx = 0.5 + (e.x - 0.5) * (0.35 + u * 0.4) + 0.05 * sin(turn * e.speed * 2 + e.phase);
      final color = u < 0.3 ? 0xFFFFF3B0 : (u < 0.65 ? 0xFFFFB347 : 0xFFF2552A);
      final alpha = u < 0.1 ? u / 0.1 : 1 - u;
      _px(canvas, _at(fx, fy), u < 0.45 ? _p * 2 : _p, _paint(color, alpha));
    }
  }

  void _prismLayer(Canvas canvas, double v, double turn) {
    if (!front) {
      _glow(canvas, _at(0.5, 0.42), _w * 0.44 * zoom, 0xFFB9A8FF, 0.5 + 0.12 * sin(turn * 2));
      _glow(canvas, _at(0.5, 0.42), _w * 0.22 * zoom, 0xFFBFF3FF, 0.45);
    }
    // Six crystals orbit the flower; the ones going round the back are
    // drawn behind the plant, the others in front.
    for (var i = 0; i < 6; i++) {
      final a = turn + i * pi / 3;
      final depth = sin(a);
      if ((depth >= 0) != front) continue;
      final c = _at(0.5 + 0.38 * cos(a), 0.42 + 0.08 * depth + 0.025 * sin(turn * 3 + i));
      final hue = (i * 60 + v * 360) % 360;
      final color = HSVColor.fromAHSV(1, hue, 0.5, 1).toColor();
      final scale = 0.75 + 0.3 * depth;
      _shard(canvas, c, (_w * zoom * 0.055 * scale / _p).round().clamp(2, 8), color, depth < 0 ? 0.6 : 1);
    }
    if (!front) return;
    for (final s in _sparks) {
      final twinkle = pow(max(0.0, sin(turn * s.speed * 2 + s.phase)), 3).toDouble();
      if (twinkle < 0.1) continue;
      final c = _at(0.12 + s.x * 0.76, 0.06 + s.y * 0.55);
      _star(canvas, c, twinkle > 0.7 ? 2 : 1, _paint(s.speed == 1 ? 0xFFFFFFFF : 0xFFBFF3FF, twinkle));
    }
  }

  /// A pixel diamond with a light left half and a darker right half.
  void _shard(Canvas canvas, Offset c, int half, Color color, double alpha) {
    final light = _paint(color.toARGB32(), alpha);
    final dark = _paint(Color.lerp(color, const Color(0xFF4B4FC8), 0.45)!.toARGB32(), alpha);
    final cx = _snap(c.dx), cy = _snap(c.dy);
    for (var row = -half; row <= half; row++) {
      final wHalf = ((half - row.abs()) * 0.6).round();
      final y = cy + row * _p;
      canvas.drawRect(Rect.fromLTWH(cx - wHalf * _p, y, (wHalf + 1) * _p, _p), light);
      if (wHalf > 0) canvas.drawRect(Rect.fromLTWH(cx + _p, y, wHalf * _p, _p), dark);
    }
    canvas.drawRect(Rect.fromLTWH(cx - _p, cy - _p * (half ~/ 2), _p, _p), _paint(0xFFFFFFFF, alpha));
  }

  void _radianceLayer(Canvas canvas, double v, double turn) {
    final center = _at(0.5, 0.3);
    if (!front) {
      // Twelve golden rays turning slowly (two ray-steps per loop).
      final radius = _w * 0.8 * zoom;
      final shader = RadialGradient(colors: [
        const Color(0xFFFFE27A).withValues(alpha: 0.5 * strength),
        const Color(0xFFFFE27A).withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: center, radius: radius));
      for (var i = 0; i < 12; i++) {
        final a = v * 2 * pi / 6 + i * pi / 6;
        final spread = i.isEven ? 0.12 : 0.07;
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(center.dx + cos(a - spread) * radius, center.dy + sin(a - spread) * radius)
          ..lineTo(center.dx + cos(a + spread) * radius, center.dy + sin(a + spread) * radius)
          ..close();
        canvas.drawPath(path, Paint()..shader = shader);
      }
      _glow(canvas, center, _w * 0.36 * zoom, 0xFFFFF1A8, 0.5 + 0.1 * sin(turn * 2));
      return;
    }
    // Golden motes floating up, and stars twinkling around the crown.
    for (final m in _motes) {
      final u = (m.y + v * m.speed) % 1.0;
      final fx = 0.18 + m.x * 0.64 + 0.03 * sin(turn * 2 + m.phase);
      final fy = 0.7 - u * 0.66;
      final alpha = u < 0.15 ? u / 0.15 : (1 - u);
      _px(canvas, _at(fx, fy), _p, _paint(m.speed == 1 ? 0xFFFFE066 : 0xFFFFFFFF, alpha));
    }
    for (final s in _sparks) {
      final twinkle = pow(max(0.0, sin(turn * s.speed * 2 + s.phase)), 3).toDouble();
      if (twinkle < 0.1) continue;
      final c = _at(0.15 + s.x * 0.7, 0.02 + s.y * 0.45);
      _star(canvas, c, twinkle > 0.7 ? 2 : 1, _paint(0xFFFFF4B0, twinkle));
    }
  }

  @override
  bool shouldRepaint(AuraPainter old) =>
      old.aura != aura || old.strength != strength || old.front != front || old.zoom != zoom || old.anchorY != anchorY;
}
