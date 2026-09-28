import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The "kuwaGO" wordmark: "kuwa" in dark brown, "G" in leaf green, and
/// the final O drawn as a little pixel clock (a nod to the Pomodoro timer).
///
///   [fontSize]  size of the pixel lettering; the clock matches it
///   [ticking]   spin the clock hands (e.g. while loading); otherwise the
///               clock rests at the classic 10:10
class KuwagoLogo extends StatelessWidget {
  const KuwagoLogo({super.key, this.fontSize = 22, this.ticking = false});

  final double fontSize;
  final bool ticking;

  @override
  Widget build(BuildContext context) {
    // Semantics reads the real name; the clock is decoration.
    return Semantics(
      label: AppInfo.name,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'kuwa', style: AppTheme.pixelHeading(size: fontSize)),
              TextSpan(text: 'G', style: AppTheme.pixelHeading(size: fontSize, color: AppColors.greenDeep)),
              WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: Padding(
                  // Same small gap the font puts between letters, and a
                  // nudge down so the clock sits on the baseline.
                  padding: EdgeInsets.only(left: fontSize * 0.1, bottom: fontSize * 0.3),
                  child: PixelClock(size: fontSize * 1.1, ticking: ticking),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round pixel-art clock on a 16×16 grid: dark outline, gold rim,
/// cream face, four tick marks, brown hour hand and green minute hand.
/// The hands are drawn pixel by pixel, so even when spinning they stay
/// crisp pixel art (no smooth rotation).
class PixelClock extends StatefulWidget {
  const PixelClock({super.key, required this.size, this.ticking = false});

  final double size;
  final bool ticking;

  @override
  State<PixelClock> createState() => _PixelClockState();
}

class _PixelClockState extends State<PixelClock> {
  // Classic "10:10" resting pose (hands in minutes around the dial).
  static const _restMinute = 10.0;
  static const _restHour = 10.0;

  Timer? _timer;
  double _minute = _restMinute;
  double _hour = _restHour;

  @override
  void initState() {
    super.initState();
    _syncTicking();
  }

  @override
  void didUpdateWidget(PixelClock old) {
    super.didUpdateWidget(old);
    if (old.ticking != widget.ticking) _syncTicking();
  }

  void _syncTicking() {
    _timer?.cancel();
    if (!widget.ticking) {
      setState(() {
        _minute = _restMinute;
        _hour = _restHour;
      });
      return;
    }
    // One "minute" step every 80 ms: the minute hand laps the dial in
    // ~5 s while the hour hand creeps along — busy, but not frantic.
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {
        _minute = (_minute + 1) % 60;
        _hour = (_hour + 1 / 12) % 12;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _ClockPainter(minute: _minute, hour: _hour),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({required this.minute, required this.hour});

  final double minute; // 0–60
  final double hour; // 0–12

  static const _grid = 16;
  static const _outline = AppColors.panelDark;
  static const _rim = AppColors.accentGold;
  static const _rimShade = Color(0xFFB8862A);
  static const _face = Color(0xFFFFF4E0);
  static const _hourHand = AppColors.panelMedium;
  static const _minuteHand = AppColors.greenDeep;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _grid;
    final paint = Paint();
    void dot(int x, int y, Color color) {
      if (x < 0 || y < 0 || x >= _grid || y >= _grid) return;
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + 0.4, cell + 0.4), paint);
    }

    const c = (_grid - 1) / 2; // 7.5 — centre between the middle pixels
    // Round body: outline ring, gold rim (shaded on the lower right), face.
    for (var y = 0; y < _grid; y++) {
      for (var x = 0; x < _grid; x++) {
        final d = sqrt(pow(x - c, 2) + pow(y - c, 2));
        if (d > 7.6) continue;
        if (d > 6.7) {
          dot(x, y, _outline);
        } else if (d > 5.4) {
          dot(x, y, (x + y) > 16 ? _rimShade : _rim);
        } else {
          dot(x, y, _face);
        }
      }
    }

    // Tick marks at 12, 3, 6 and 9.
    for (final t in const [[7, 2], [8, 2], [13, 7], [13, 8], [7, 13], [8, 13], [2, 7], [2, 8]]) {
      dot(t[0], t[1], _outline);
    }

    // Hands: stepped pixel lines from the centre.
    void hand(double turns, double length, Color color) {
      final a = turns * 2 * pi - pi / 2; // 0 = pointing up
      for (var r = 0.0; r <= length; r += 0.5) {
        dot((c + cos(a) * r).round(), (c + sin(a) * r).round(), color);
      }
    }

    hand(hour / 12, 3.2, _hourHand);
    hand(minute / 60, 4.6, _minuteHand);
    // Centre pin.
    dot(7, 7, _outline);
    dot(8, 7, _outline);
    dot(7, 8, _outline);
    dot(8, 8, _outline);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.minute != minute || old.hour != hour;
}
