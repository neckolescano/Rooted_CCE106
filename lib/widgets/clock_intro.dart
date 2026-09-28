import 'dart:math';
import 'package:flutter/material.dart';
import '../art/wordmark_art.dart';
import '../services/intro_cue.dart';
import '../services/splash_bridge.dart';
import 'kuwago_lockup.dart';
import 'owl_mascot.dart';

/// The kuwaGO opening — "through the O":
///
///  WIND-UP  the kuwaGO lockup (kuwago perched on the clock O) on leaf
///           green; the minute hand winds one lap while kuwago bobs. On
///           Android 12+ the phone's own splash plays this the instant the
///           icon is pressed (res/drawable/splash_lockup_anim.xml) and we
///           carry on from its last frame; otherwise we play it here.
///  TICK     while the app is still loading, the clock keeps ticking and
///           kuwago blinks. (No loading bar — the clock IS the waiting.)
///  DING     the app is ready: the clock bounces with a golden "ding".
///  OPEN     a pixel circle bursts out of the O and opens onto the app.
///           Then the continuation:
///             • login page → the lockup glides onto the login sign
///             • home page  → the letters float away and kuwago flies to
///                            its spot on the greenhouse windowsill
///
/// It sits ON TOP of the real app (see BootApp in main.dart), which is
/// why the circle can reveal it.
class ClockIntro extends StatefulWidget {
  const ClockIntro({super.key, required this.appReady, required this.onRevealed});

  /// true once the real app has been built underneath.
  final bool appReady;

  /// Called when the app is fully revealed (the opening can be removed).
  final VoidCallback onRevealed;

  static const background = Color(splashGreen);

  @override
  State<ClockIntro> createState() => _ClockIntroState();
}

// ---- Timing — tweak these to retime the opening ----
const _minTick = Duration(milliseconds: 250); // tick at least this long after the wind-up
const int _windUpMs = 900; // same as the phone's splash animation
const int _dingMs = 340;
const int _openMs = 850;
const int _tickEveryMs = 80; // one clock minute per 80 ms while waiting

class _ClockIntroState extends State<ClockIntro> with TickerProviderStateMixin {
  // Keeps frames coming for the ticking clock and blinks.
  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  late final AnimationController _windUp = AnimationController(vsync: this, duration: const Duration(milliseconds: _windUpMs));
  late final AnimationController _pattern = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final AnimationController _ding = AnimationController(vsync: this, duration: const Duration(milliseconds: _dingMs));
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: _openMs));

  final Stopwatch _ticking = Stopwatch();
  Offset? _center; // where the phone's splash drew the lockup
  bool _handedOff = false;
  bool _tickedEnough = false;
  bool _opening = false;

  // Where things land (found once the app is laid out underneath).
  Rect? _lockupTarget; // login sign
  Rect? _owlTarget; // home windowsill
  // The clock's time when the ding started (the hands sweep home from it).
  double _dingFromMinute = restMinute;

  late final List<_Leaf> _leaves = _Leaf.scatter(Random(5));

  @override
  void initState() {
    super.initState();
    _open.addListener(() {
      // Let the page start its entrance while the circle is opening.
      if (_open.value > 0.3 && IntroCue.stage.value == IntroStage.covering) {
        IntroCue.stage.value = IntroStage.revealing;
      }
    });
    // Frame 1 = the lockup at rest, exactly like the splash.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handOff());
  }

  Future<void> _handOff() async {
    final splash = await SplashBridge.handoff();
    if (!mounted) return;
    if (splash != null) {
      // Line up with the splash to the pixel, then reveal ourselves under it.
      setState(() => _center = splash);
      await WidgetsBinding.instance.endOfFrame;
      await SplashBridge.remove();
    } else {
      // No animated splash (older Android, web preview): wind up here.
      await _windUp.forward();
    }
    if (!mounted) return;
    debugPrint('[Intro] ${splash == null ? 'played the wind-up here' : 'continuing from the splash at $splash'}');
    _handedOff = true;
    _ticking.start();
    _pattern.forward();
    Future<void>.delayed(_minTick, () {
      _tickedEnough = true;
      _maybeOpen();
    });
  }

  @override
  void didUpdateWidget(ClockIntro old) {
    super.didUpdateWidget(old);
    if (widget.appReady && !old.appReady) _maybeOpen();
  }

  Future<void> _maybeOpen() async {
    if (!mounted || !_handedOff || !_tickedEnough || !widget.appReady || _opening) return;
    _opening = true;
    // Let the app underneath lay out, then find where the pieces land.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _lockupTarget = IntroCue.rectOf(IntroCue.loginLockupKey);
    _owlTarget = _lockupTarget == null ? IntroCue.rectOf(IntroCue.homeOwlKey) : null;
    _dingFromMinute = _minuteNow();
    debugPrint('[Intro] opening onto ${_lockupTarget != null ? 'the login page' : _owlTarget != null ? 'the home page' : 'the app'}');
    await _ding.forward();
    if (!mounted) return;
    await _open.forward();
    if (mounted) widget.onRevealed();
  }

  /// The clock's minute hand right now (winding up, then ticking).
  double _minuteNow() {
    if (!_handedOff) {
      // Wind-up: one lap in 5-minute steps, back to 10:10.
      final step = (_windUp.value * 12).floor();
      return restMinute + step * 5;
    }
    return restMinute + _ticking.elapsedMilliseconds / _tickEveryMs;
  }

  @override
  void dispose() {
    _ambient.dispose();
    _windUp.dispose();
    _pattern.dispose();
    _ding.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'kuwaGO is starting',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambient, _windUp, _pattern, _ding, _open]),
        builder: (context, _) => LayoutBuilder(builder: (context, box) => _build(box.biggest)),
      ),
    );
  }

  static double _seg(double v, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((v - a) / (b - a)).clamp(0.0, 1.0));

  Widget _build(Size size) {
    final c = _center ?? size.center(Offset.zero);
    final home = Rect.fromCenter(center: c, width: KuwagoLockup.size.width, height: KuwagoLockup.size.height);
    final clockAt = home.topLeft + KuwagoLockup.clockCenter; // centre of the O
    final d = _ding.value, o = _open.value;
    final ms = _ambient.lastElapsedDuration?.inMilliseconds ?? 0;

    // ---- Clock hands: wind-up → ticking → sweep home (10:10) on the ding ----
    double minute;
    if (_opening && d > 0 || o > 0) {
      // Finish the current lap back to 10:10 during the ding.
      final from = _dingFromMinute;
      final to = (from / 60).ceil() * 60 + restMinute;
      minute = from + (to - from) * Curves.easeOutCubic.transform(d);
    } else {
      minute = _minuteNow();
    }
    // Only the minute hand moves, so the clock always lands back on the
    // exact 10:10 of the splash and the login sign.
    const hour = restHour;
    final clockScale = 1 + 0.18 * sin(pi * d);

    // ---- kuwago ----
    final windBob = _handedOff ? 0.0 : sin(_windUp.value * pi * 4).abs() * 3; // bobs twice, like the splash
    final blink = !_opening && _handedOff && (ms % 2600) < 130;
    final dingHop = sin(pi * d) * 6;
    final owlFlapping = d > 0 && d < 1 || (o > 0 && o < 0.9 && _owlTarget != null);
    final wingsUp = owlFlapping && ((ms ~/ 90).isEven);

    // ---- Opening circle ----
    final farthest = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)]
        .map((corner) => (corner - clockAt).distance)
        .reduce(max);
    final hole = farthest * Curves.easeInCubic.transform(_seg(o, 0, 0.8));

    // ---- Where the lockup is (it flies onto the login sign) ----
    final fly = Curves.easeInOutCubic.transform(_seg(o, 0.1, 0.85));
    Rect lockupRect = home;
    double lockupOpacity = 1;
    if (_lockupTarget != null) {
      lockupRect = Rect.lerp(home, _lockupTarget, fly)!;
    } else if (o > 0) {
      // Home: the letters float up and dissolve.
      lockupRect = home.shift(Offset(0, -36 * Curves.easeOut.transform(_seg(o, 0.1, 0.7))));
      lockupOpacity = 1 - _seg(o, 0.15, 0.6);
    }

    // kuwago leaves the clock and flies to the windowsill (home only).
    final owlAtHome = home.topLeft + KuwagoLockup.owlRect.topLeft;
    final owlSize = KuwagoLockup.owlRect.width;
    Rect? owlFlight;
    if (_owlTarget != null && o > 0) {
      final t = Curves.easeInOutCubic.transform(_seg(o, 0.05, 0.9));
      final start = Rect.fromLTWH(owlAtHome.dx, owlAtHome.dy - dingHop, owlSize, owlSize);
      owlFlight = Rect.lerp(start, _owlTarget, t)!.shift(Offset(0, -70 * sin(pi * t)));
    }

    final background = Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: ClockIntro.background)),
        Positioned.fill(
          child: Opacity(
            opacity: _pattern.value,
            child: RepaintBoundary(child: CustomPaint(painter: _LeafPatternPainter(_leaves))),
          ),
        ),
      ],
    );

    return IgnorePointer(
      ignoring: o > 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The green, with a pixel circle opening onto the app.
          Positioned.fill(
            child: o == 0
                ? background
                : ClipPath(
                    clipBehavior: Clip.hardEdge,
                    clipper: _PixelHoleClipper(center: clockAt, radius: hole),
                    child: background,
                  ),
          ),
          // A golden rim around the opening circle.
          if (o > 0 && hole > 0)
            Positioned.fill(
              child: CustomPaint(painter: _HoleRimPainter(center: clockAt, radius: hole, opacity: 1 - _seg(o, 0.6, 0.9))),
            ),
          // "Ding!" — gold sparks around the clock.
          if (d > 0 && d < 1)
            Positioned.fill(child: CustomPaint(painter: _DingPainter(center: clockAt, t: d))),
          // The lockup.
          Positioned.fromRect(
            rect: lockupRect,
            child: Opacity(
              opacity: lockupOpacity,
              // FittedBox: grows smoothly if the landing spot is bigger.
              child: FittedBox(
                fit: BoxFit.fill,
                child: KuwagoLockup(
                minute: minute,
                hour: hour,
                clockScale: clockScale,
                showOwl: owlFlight == null,
                owlBlink: blink,
                owlWingsUp: wingsUp,
                owlLift: windBob + dingHop,
                ),
              ),
            ),
          ),
          // kuwago flying to the windowsill.
          if (owlFlight != null)
            Positioned.fromRect(
              rect: owlFlight,
              child: OwlSprite(size: owlFlight.width, perch: false, wingsUp: wingsUp, look: -1),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

Paint _pixel(Color color) => Paint()
  ..isAntiAlias = false
  ..color = color;

class _Leaf {
  const _Leaf(this.x, this.y, this.flip, this.dark);

  final double x, y; // dp from the top-left of a 360-wide tile
  final bool flip, dark;

  /// A loose, staggered grid of tiny leaves.
  static List<_Leaf> scatter(Random r) => [
        for (var row = 0; row < 40; row++)
          for (var col = 0; col < 9; col++)
            _Leaf(col * 44.0 + (row.isOdd ? 22 : 0) + r.nextDouble() * 10, row * 40.0 + r.nextDouble() * 10,
                r.nextBool(), r.nextDouble() < 0.4),
      ];
}

/// Faint pixel leaves all over the green, so it's never a flat colour.
class _LeafPatternPainter extends CustomPainter {
  _LeafPatternPainter(this.leaves);

  final List<_Leaf> leaves;

  static const _shape = ['.##', '###', '##.', '#..']; // a tiny leaf with a stem
  static const double _px = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final light = _pixel(const Color(0xFFCDE5B5));
    final dark = _pixel(const Color(0xFFC4DFA9));
    for (final leaf in leaves) {
      if (leaf.y > size.height + 10) continue;
      for (var tile = 0.0; tile < size.width; tile += 396) {
        final ox = tile + leaf.x, oy = leaf.y;
        if (ox > size.width) break;
        for (var y = 0; y < _shape.length; y++) {
          for (var x = 0; x < 3; x++) {
            final cx = leaf.flip ? 2 - x : x;
            if (_shape[y][cx] != '#') continue;
            canvas.drawRect(
              Rect.fromLTWH((ox / _px).round() * _px + x * _px, (oy / _px).round() * _px + y * _px, _px, _px),
              leaf.dark ? dark : light,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LeafPatternPainter old) => false;
}

/// Eight gold sparks bursting out of the clock: "ding!"
class _DingPainter extends CustomPainter {
  _DingPainter({required this.center, required this.t});

  final Offset center;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _pixel(const Color(0xFFE8B84B).withValues(alpha: sin(pi * t)));
    final r = 26 + 18 * Curves.easeOut.transform(t);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      final p = center + Offset(cos(a), sin(a)) * r;
      final len = i.isEven ? 3.0 : 2.0;
      canvas.drawRect(Rect.fromCenter(center: Offset(p.dx.roundToDouble(), p.dy.roundToDouble()), width: 2.5 * len, height: 2.5 * len), paint);
    }
  }

  @override
  bool shouldRepaint(_DingPainter old) => old.t != t;
}

/// Stepped circle rows — shared by the hole and its rim.
Iterable<Rect> _pixelCircleRows(Offset center, double radius) sync* {
  final step = max(6.0, (radius / 25).roundToDouble());
  for (var y = -radius; y < radius; y += step) {
    final mid = y + step / 2;
    final half = (sqrt(max(0.0, radius * radius - mid * mid)) / step).round() * step;
    if (half <= 0) continue;
    yield Rect.fromLTRB(center.dx - half, center.dy + y, center.dx + half, center.dy + y + step);
  }
}

/// Everything EXCEPT a pixel-stepped circle — the window onto the app.
class _PixelHoleClipper extends CustomClipper<Path> {
  _PixelHoleClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (radius > 0) {
      for (final row in _pixelCircleRows(center, radius)) {
        path.addRect(row);
      }
    }
    return path;
  }

  @override
  bool shouldReclip(_PixelHoleClipper old) => old.radius != radius || old.center != center;
}

/// A chunky gold edge around the opening circle.
class _HoleRimPainter extends CustomPainter {
  _HoleRimPainter({required this.center, required this.radius, required this.opacity});

  final Offset center;
  final double radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final gold = _pixel(const Color(0xFFE8B84B).withValues(alpha: opacity));
    const w = 5.0;
    for (final row in _pixelCircleRows(center, radius)) {
      canvas.drawRect(Rect.fromLTWH(row.left - w, row.top, w, row.height), gold);
      canvas.drawRect(Rect.fromLTWH(row.right, row.top, w, row.height), gold);
    }
  }

  @override
  bool shouldRepaint(_HoleRimPainter old) => old.radius != radius || old.opacity != opacity;
}
