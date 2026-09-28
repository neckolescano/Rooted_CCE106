import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A rolled paper scroll, drawn in code: a rolled-up paper tube with
/// wooden knobs at the top and bottom, and aged parchment in between
/// (paper grain, darker worn edges, slightly ragged sides).
///
/// Used behind every popup so they feel like notes and letters from the
/// garden instead of plain boxes. Optionally wears a wax seal ([seal]).
class PixelScroll extends StatelessWidget {
  const PixelScroll({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 18),
    this.seal,
  });

  final Widget child;
  final EdgeInsets padding;

  /// Optional wax seal pressed onto the top roll (see [WaxSeal]).
  final WaxSeal? seal;

  static const double _rodHeight = 20;

  @override
  Widget build(BuildContext context) {
    final sealSize = seal?.size ?? 0;
    // Room for the half of the seal that hangs below the top roll.
    final extraTop = seal == null ? 0.0 : sealSize / 2;

    final scroll = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _rodHeight, child: CustomPaint(painter: _RodPainter(top: true))),
        Flexible(
          child: Padding(
            // Paper is a little narrower than the rolls, like a real scroll.
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CustomPaint(
              painter: _PaperPainter(),
              child: Padding(
                padding: padding.copyWith(top: padding.top + extraTop),
                child: child,
              ),
            ),
          ),
        ),
        const SizedBox(height: _rodHeight, child: CustomPaint(painter: _RodPainter(top: false))),
      ],
    );

    if (seal == null) return scroll;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: EdgeInsets.only(top: sealSize / 2 - _rodHeight / 2), child: scroll),
        Positioned(top: 0, left: 0, right: 0, child: Center(child: seal!)),
      ],
    );
  }
}

/// A round wax seal with an icon stamped in it.
class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, required this.icon, this.color = WaxSeal.red, this.size = 48});

  final IconData icon;
  final Color color;
  final double size;

  // Seal colors that fit the palette.
  static const red = Color(0xFFA8392C); // warnings: sign out, give up
  static const green = Color(0xFF4E7A2C); // friendly info: about, plants
  static const gold = Color(0xFFC08A1E); // rewards: badges

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SealPainter(color),
        child: Center(
          child: Icon(icon, size: size * 0.42, color: const Color(0xFFFFF1DC)),
        ),
      ),
    );
  }
}

/// Paper tube + wooden knobs. Light band on top, shadowed band at the
/// bottom, so it reads as round.
class _RodPainter extends CustomPainter {
  const _RodPainter({required this.top});

  final bool top;

  static const double px = AppSizes.artScale;
  static const double knob = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()..color = AppColors.panelDark;
    final h = size.height;
    final body = Rect.fromLTRB(knob - px, px, size.width - knob + px, h - px);

    // Soft shadow the roll casts on the paper.
    canvas.drawRect(
      Rect.fromLTWH(knob + 6, top ? h - px : 0, size.width - (knob + 6) * 2, px),
      Paint()..color = const Color(0x33000000),
    );

    // Paper tube.
    canvas.drawRect(body.inflate(px), outline);
    canvas.drawRect(body, Paint()..color = const Color(0xFFEBD2A6));
    canvas.drawRect(Rect.fromLTWH(body.left, body.top, body.width, px * 2), Paint()..color = const Color(0xFFFFF1DA));
    canvas.drawRect(Rect.fromLTWH(body.left, body.center.dy, body.width, px), Paint()..color = const Color(0xFFD9BC8C));
    canvas.drawRect(Rect.fromLTWH(body.left, body.bottom - px * 2, body.width, px * 2), Paint()..color = const Color(0xFFC4A274));
    // The curled paper edge where it rolls under.
    canvas.drawRect(Rect.fromLTWH(body.left + 6, top ? body.bottom - px * 3 : body.top + px, body.width - 12, px),
        Paint()..color = const Color(0xFFB08E62));

    // Wooden knobs on both ends.
    for (final left in [0.0, size.width - knob]) {
      final k = Rect.fromLTWH(left, 0, knob, h);
      canvas.drawRect(k, outline);
      final inner = k.deflate(px);
      canvas.drawRect(inner, Paint()..color = AppColors.panelMedium);
      canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, px, inner.height), Paint()..color = AppColors.panelLight);
      canvas.drawRect(Rect.fromLTWH(inner.right - px, inner.top, px, inner.height), Paint()..color = const Color(0xFF6B4226));
    }
  }

  @override
  bool shouldRepaint(_RodPainter old) => old.top != top;
}

/// Aged parchment: base color, grain specks and fibers (same pattern
/// every time — fixed random seed), darker worn edges, ragged sides.
class _PaperPainter extends CustomPainter {
  static const double px = AppSizes.artScale;
  static const _paper = Color(0xFFF4DCB2);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Paper in 8px rows; every third row steps in one pixel on both sides,
    // which gives the ragged, hand-cut edge.
    double stepAt(double y) => ((y / 8).floor() % 3 == 0) ? px : 0.0;
    final paper = Paint()..color = _paper;
    for (var y = 0.0; y < h; y += 8) {
      final step = stepAt(y);
      canvas.drawRect(Rect.fromLTWH(step, y, w - step * 2, math.min(8.0, h - y)), paper);
    }

    // Worn, slightly darker band along the edges.
    final worn = Paint()..color = const Color(0xFFE7C895);
    canvas.drawRect(Rect.fromLTWH(px, 0, px * 3, h), worn);
    canvas.drawRect(Rect.fromLTWH(w - px * 4, 0, px * 3, h), worn);

    // Grain: small specks and short fibers.
    final random = math.Random(42);
    final speck = Paint()..color = const Color(0xFFD9B98A);
    final light = Paint()..color = const Color(0xFFFFF0D6);
    final count = (w * h / 380).clamp(10, 900).toInt();
    for (var i = 0; i < count; i++) {
      final x = (random.nextDouble() * (w - 8) + 4).floorToDouble();
      final y = (random.nextDouble() * (h - 4) + 2).floorToDouble();
      final roll = random.nextDouble();
      if (roll < 0.55) {
        canvas.drawRect(Rect.fromLTWH(x, y, px, px), speck);
      } else if (roll < 0.8) {
        canvas.drawRect(Rect.fromLTWH(x, y, px * 3, px), light);
      } else {
        canvas.drawRect(Rect.fromLTWH(x, y, px * 2, px), speck);
      }
    }

    // Ragged left/right edges: an outline that steps in and out.
    final outline = Paint()..color = const Color(0xFF8A6A48);
    for (var y = 0.0; y < h; y += 8) {
      final step = stepAt(y);
      final segment = math.min(8.0, h - y);
      canvas.drawRect(Rect.fromLTWH(step, y, px, segment), outline);
      canvas.drawRect(Rect.fromLTWH(w - px - step, y, px, segment), outline);
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) => false;
}

/// A chunky pixel circle with a darker rim and a lit top-left, like a
/// blob of pressed wax.
class _SealPainter extends CustomPainter {
  _SealPainter(this.color);

  final Color color;

  static const double px = AppSizes.artScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final dark = Color.lerp(color, Colors.black, 0.4)!;
    final lit = Color.lerp(color, Colors.white, 0.25)!;

    // A circle made of horizontal pixel rows (so the edge stays blocky).
    void disc(double inset, Color c) {
      final r = s / 2 - inset;
      final paint = Paint()..color = c;
      for (var y = -r; y < r; y += px) {
        final half = math.sqrt(math.max(0, r * r - (y + px / 2) * (y + px / 2)));
        final snapped = (half / px).floorToDouble() * px;
        canvas.drawRect(Rect.fromLTWH(s / 2 - snapped, s / 2 + y, snapped * 2, px), paint);
      }
    }

    canvas.drawRect(Rect.fromLTWH(s * 0.2, s - px, s * 0.6, px), Paint()..color = const Color(0x33000000));
    disc(0, AppColors.panelDark);
    disc(px, dark);
    disc(px * 2, color);
    // Pressed ring inside the seal.
    disc(s * 0.16, dark);
    disc(s * 0.16 + px, color);
    // Shine.
    canvas.drawRect(Rect.fromLTWH(s * 0.28, s * 0.2, px * 2, px), Paint()..color = lit);
    canvas.drawRect(Rect.fromLTWH(s * 0.22, s * 0.26, px, px * 2), Paint()..color = lit);
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.color != color;
}
