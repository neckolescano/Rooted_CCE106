import 'package:flutter/material.dart';
import '../art/wordmark_art.dart';
import 'owl_mascot.dart';

/// The kuwaGO lockup — pixel wordmark, clock O, kuwago perched on the
/// clock — drawn from lib/art/wordmark_art.dart. It is the exact picture
/// on the phone's launch splash, so the opening can carry it on seamlessly
/// (and the login page's sign shows the same letters and clock).
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
