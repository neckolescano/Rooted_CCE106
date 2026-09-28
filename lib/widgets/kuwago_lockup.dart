import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../art/wordmark_art.dart';
import '../theme/app_theme.dart';
import 'owl_mascot.dart';

/// The kuwaGO lockup — pixel wordmark, clock O, kuwago perched on the
/// clock — drawn from lib/art/wordmark_art.dart. It is the exact picture
/// on the phone's launch splash, so the opening and the login sign can
/// carry it on seamlessly.
class KuwagoLockup extends StatelessWidget {
  const KuwagoLockup({
    super.key,
    this.minute = restMinute,
    this.hour = restHour,
    this.clockScale = 1,
    this.showOwl = true,
    this.owlLook = 0,
    this.owlBlink = false,
    this.owlWingsUp = false,
    this.owlLift = 0,
  });

  final double minute; // 0–60
  final double hour; // 0–12
  final double clockScale; // bounce on the "ding"
  final bool showOwl;
  final int owlLook;
  final bool owlBlink;
  final bool owlWingsUp;
  final double owlLift; // dp the owl hops up

  static const double px = lockupPixelDp;
  static const Size size = Size(lockupWidth * px, lockupHeight * px);

  /// Centre of the clock O inside the lockup.
  static const Offset clockCenter = Offset(clockCenterX * px, clockCenterY * px);

  /// Where the owl sits inside the lockup (its 24-px box).
  static const Rect owlRect = Rect.fromLTWH(
    (owlLeft - lockupLeft) * px,
    (owlTop - lockupTop) * px,
    24 * px,
    24 * px,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _LettersPainter()))),
          Positioned(
            left: (clockLeft - lockupLeft) * px,
            top: -lockupTop * px,
            width: clockGrid * px,
            height: clockGrid * px,
            child: Transform.scale(
              scale: clockScale,
              child: CustomPaint(painter: LockupClockPainter(minute: minute, hour: hour)),
            ),
          ),
          if (showOwl)
            Positioned.fromRect(
              rect: owlRect.shift(Offset(0, -owlLift)),
              child: OwlSprite(
                size: owlRect.width,
                perch: false,
                look: owlLook,
                blink: owlBlink,
                wingsUp: owlWingsUp,
              ),
            ),
        ],
      ),
    );
  }
}

/// The login-sign version: kuwago blinks now and then, and hops with a
/// "Hoo!" when tapped.
class LiveKuwagoLockup extends StatefulWidget {
  const LiveKuwagoLockup({super.key});

  @override
  State<LiveKuwagoLockup> createState() => _LiveKuwagoLockupState();
}

class _LiveKuwagoLockupState extends State<LiveKuwagoLockup> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  Timer? _blinkTimer;
  bool _blink = false;
  int _look = 0;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(Duration(milliseconds: 2200 + _random.nextInt(2400)), () async {
      if (!mounted) return;
      setState(() {
        _blink = true;
        _look = _random.nextInt(3) - 1; // glance somewhere new after blinking
      });
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      setState(() => _blink = false);
      _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hop,
      builder: (context, _) {
        final t = _hop.value;
        final hopping = _hop.isAnimating;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            KuwagoLockup(
              owlLook: _look,
              owlBlink: _blink,
              owlWingsUp: hopping && (t * 8).floor().isEven,
              owlLift: hopping ? sin(pi * min(1.0, t / 0.5)) * 10 : 0,
            ),
            // Tap target over the owl.
            Positioned.fromRect(
              rect: KuwagoLockup.owlRect,
              child: Semantics(
                button: true,
                label: 'kuwago the owl',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _hop.forward(from: 0),
                ),
              ),
            ),
            if (hopping && t < 0.85)
              Positioned(
                left: KuwagoLockup.owlRect.right - 6,
                top: KuwagoLockup.owlRect.top - 14,
                child: Opacity(
                  opacity: 1 - ((t - 0.6) / 0.25).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.parchment,
                      border: Border.all(color: AppColors.panelDark, width: 2),
                    ),
                    child: Text('Hoo!', style: AppTheme.pixelHeading(size: 8)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Paint _pixel(int argb) => Paint()
  ..isAntiAlias = false
  ..color = Color(argb);

class _LettersPainter extends CustomPainter {
  const _LettersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const px = lockupPixelDp;
    for (final (x, y, color) in letterPixels()) {
      canvas.drawRect(Rect.fromLTWH((x - lockupLeft) * px, (y - lockupTop) * px, px, px), _pixel(color));
    }
  }

  @override
  bool shouldRepaint(_LettersPainter old) => false;
}

/// The clock O at any time, pixel for pixel like the splash.
class LockupClockPainter extends CustomPainter {
  const LockupClockPainter({required this.minute, required this.hour});

  final double minute;
  final double hour;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / clockGrid;
    void dot(int x, int y, int color) => canvas.drawRect(Rect.fromLTWH(x * px, y * px, px, px), _pixel(color));
    for (final (x, y, color) in clockBodyPixels()) {
      dot(x, y, color);
    }
    for (final (x, y) in clockHand(hour / 12, hourHandLength)) {
      dot(x, y, clockHourHand);
    }
    for (final (x, y) in clockHand(minute / 60, minuteHandLength)) {
      dot(x, y, clockMinuteHand);
    }
    for (final (x, y) in clockPin) {
      dot(x, y, clockOutline);
    }
  }

  @override
  bool shouldRepaint(LockupClockPainter old) => old.minute != minute || old.hour != hour;
}
