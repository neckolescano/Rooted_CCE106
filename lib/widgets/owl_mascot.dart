import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../art/owl_art.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// Draws one frame of the owl (see lib/art/owl_art.dart). Use a [size]
/// that's a multiple of 24 so every art pixel is a whole number of dp.
class OwlSprite extends StatelessWidget {
  const OwlSprite({
    super.key,
    required this.size,
    this.look = 0,
    this.blink = false,
    this.wingsUp = false,
    this.perch = true,
  });

  final double size;
  final int look;
  final bool blink;
  final bool wingsUp;
  final bool perch;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _OwlPainter(owlRows(look: look, blink: blink, wingsUp: wingsUp, perch: perch)),
    );
  }
}

class _OwlPainter extends CustomPainter {
  _OwlPainter(this.rows);

  final List<String> rows;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / owlGrid;
    final paint = Paint();
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final color = owlColors[row[x]];
        if (color == null) continue;
        paint.color = Color(color);
        // +0.5 overlap hides hairline gaps between pixels on some screens.
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OwlPainter old) => old.rows.join() != rows.join();
}

/// The owl, alive: breathes, blinks, looks where it's told, and when
/// tapped it flaps, hops, pops little hearts and says something.
class OwlMascot extends StatefulWidget {
  const OwlMascot({
    super.key,
    this.size = 144,
    this.look = 0,
    this.cheering = false,
    this.showHint = false,
    this.messages = defaultMessages,
    this.perch = true,
    this.wander = false,
    this.floatingBubble = false,
    this.cheerLine = "Let's grow!",
  });

  final double size;

  /// -1 left, 0 ahead, 1 right — e.g. following the loading flower.
  final int look;

  /// Wings up + [cheerLine] (e.g. when loading finishes).
  final bool cheering;
  final String cheerLine;

  /// false = no branch; the owl stands on its feet (e.g. on a windowsill).
  /// Its feet are then at 21/24 of [size] from the top.
  final bool perch;

  /// Glance around by itself every few seconds (ignores [look]).
  final bool wander;

  /// true = the speech bubble floats above the owl (right-aligned, takes
  /// no layout space) — for placing the owl inside a scene. false = the
  /// bubble gets its own reserved row above the owl.
  final bool floatingBubble;

  /// Shows a small "Tap me!" under the owl until it's tapped.
  final bool showHint;

  /// What it says when tapped, in order.
  final List<String> messages;

  static const defaultMessages = [
    'Hoo! Ready to study?',
    'Your garden is waking up…',
    'Tip: 25 minutes of focus, then a break!',
    'Every session grows a leaf!',
    'Stay cozy, stay curious.',
    'Hoo-ray, almost there!',
  ];

  @override
  State<OwlMascot> createState() => _OwlMascotState();
}

class _OwlMascotState extends State<OwlMascot> with TickerProviderStateMixin {
  late final AnimationController _breathe =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final AnimationController _flap =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  final _random = Random();
  Timer? _blinkTimer;
  Timer? _bubbleTimer;
  Timer? _hintTimer;
  Timer? _wanderTimer;
  bool _blink = false;
  bool _hintVisible = false;
  int _taps = 0;
  int _wanderLook = -1;
  String? _bubble;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
    if (widget.wander) _scheduleWander();
    if (widget.showHint) {
      _hintTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _taps == 0) setState(() => _hintVisible = true);
      });
    }
  }

  @override
  void didUpdateWidget(OwlMascot old) {
    super.didUpdateWidget(old);
    if (widget.cheering && !old.cheering) {
      _say(widget.cheerLine);
      _flap.forward(from: 0);
    }
  }

  /// Every 2.5–5 s, glance somewhere else (left / ahead / right).
  void _scheduleWander() {
    _wanderTimer = Timer(Duration(milliseconds: 2500 + _random.nextInt(2500)), () {
      if (!mounted) return;
      setState(() => _wanderLook = _random.nextInt(3) - 1);
      _scheduleWander();
    });
  }

  @override
  void dispose() {
    _breathe.dispose();
    _flap.dispose();
    _blinkTimer?.cancel();
    _bubbleTimer?.cancel();
    _hintTimer?.cancel();
    _wanderTimer?.cancel();
    super.dispose();
  }

  /// Blinks every 2–4 seconds, at slightly random times (like a real owl).
  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 1800 + _random.nextInt(2200)), () {
      if (!mounted) return;
      setState(() => _blink = true);
      _blinkTimer = Timer(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        setState(() => _blink = false);
        _scheduleBlink();
      });
    });
  }

  void _say(String text) {
    _bubbleTimer?.cancel();
    setState(() => _bubble = text);
    _bubbleTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _bubble = null);
    });
  }

  void _onTap() {
    _taps++;
    _hintVisible = false;
    // A little secret for persistent tappers.
    final text = _taps % 7 == 0 ? 'Hoo-hoo! That tickles!' : widget.messages[(_taps - 1) % widget.messages.length];
    _say(text);
    _flap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cell = widget.size / owlGrid;
    final look = widget.wander ? _wanderLook : widget.look;

    final bubble = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        alignment: widget.floatingBubble ? Alignment.bottomRight : Alignment.bottomCenter,
        child: child,
      ),
      child: _bubble == null
          ? const SizedBox.shrink()
          : _SpeechBubble(key: ValueKey(_bubble), text: _bubble!, tailRight: widget.floatingBubble),
    );

    final owl = Semantics(
          button: true,
          label: 'Owl mascot. Tap to say hi.',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: _onTap,
            child: AnimatedBuilder(
              animation: Listenable.merge([_breathe, _flap]),
              builder: (context, _) {
                final flapping = _flap.isAnimating;
                final wingsUp = widget.cheering || (flapping && (_flap.value * 8).floor().isEven);
                // Breathing: a 1-art-pixel rise; hop: a quick jump while flapping.
                final breathe = _breathe.value < 0.5 ? 0.0 : -cell;
                final hop = flapping ? -sin(_flap.value * pi) * cell * 3 : 0.0;
                final y = ((breathe + hop) / cell).round() * cell; // stay on the pixel grid

                return SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Transform.translate(
                        offset: Offset(0, y),
                        child: OwlSprite(
                          size: widget.size,
                          look: flapping ? 0 : look,
                          blink: _blink && !flapping,
                          wingsUp: wingsUp,
                          perch: widget.perch,
                        ),
                      ),
                      if (_taps > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(_taps),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 900),
                              builder: (context, t, _) => CustomPaint(painter: _HeartsPainter(t, cell)),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );

    if (widget.floatingBubble) {
      // Bubble hovers above the owl's head, extending to the LEFT (so an
      // owl near the right edge of a scene doesn't push it off-screen).
      return Stack(
        clipBehavior: Clip.none,
        children: [
          owl,
          Positioned(
            right: widget.size * 0.1,
            bottom: widget.size * 0.82,
            child: IgnorePointer(child: bubble),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speech bubble (space is always reserved so nothing jumps).
        SizedBox(height: 52, child: Align(alignment: Alignment.bottomCenter, child: bubble)),
        owl,
        if (widget.showHint)
          SizedBox(
            height: 22,
            child: AnimatedOpacity(
              opacity: _hintVisible ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Text('Tap me!', style: AppText.caption(color: AppColors.panelMedium).copyWith(fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}

/// Parchment speech bubble with a little pixel tail pointing down —
/// centred, or near the right edge when [tailRight].
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({super.key, required this.text, this.tailRight = false});

  final String text;
  final bool tailRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: tailRight ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tailRight ? 200 : 240),
          child: PixelPanel(
            style: PanelStyle.parchment,
            expand: false,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 12, weight: FontWeight.w800),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(tailRight ? -14 : 0, -2),
          child: const SizedBox(width: 12, height: 8, child: CustomPaint(painter: _TailPainter())),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter();

  static const double px = AppSizes.artScale;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.parchment;
    final line = Paint()..color = AppColors.panelDark;
    // Stepped triangle: each row 2 px narrower on both sides.
    for (var i = 0; i < 3; i++) {
      final left = i * px, right = size.width - i * px;
      canvas.drawRect(Rect.fromLTWH(left, i * px, right - left, px), fill);
      canvas.drawRect(Rect.fromLTWH(left, i * px, px, px), line);
      canvas.drawRect(Rect.fromLTWH(right - px, i * px, px, px), line);
    }
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - px, 3 * px, px * 2, px), line);
  }

  @override
  bool shouldRepaint(_TailPainter old) => false;
}

/// Three little pixel hearts floating up and fading (after a tap).
class _HeartsPainter extends CustomPainter {
  _HeartsPainter(this.t, this.cell);

  final double t; // 0..1
  final double cell;

  static const _shape = ['.x.x.', 'xxxxx', '.xxx.', '..x..'];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final alpha = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    final paint = Paint()..color = const Color(0xFFD9573F).withValues(alpha: alpha);
    final px = max(2.0, (cell / 2).roundToDouble());
    for (final spot in const [[0.18, 0.35, 0.0], [0.78, 0.3, 0.15], [0.5, 0.12, 0.3]]) {
      final local = ((t - spot[2]) / (1 - spot[2])).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final x = size.width * spot[0];
      final y = size.height * spot[1] - local * cell * 6;
      for (var r = 0; r < _shape.length; r++) {
        for (var c = 0; c < _shape[r].length; c++) {
          if (_shape[r][c] == 'x') canvas.drawRect(Rect.fromLTWH(x + c * px, y + r * px, px, px), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeartsPainter old) => old.t != t;
}
