import 'dart:math';
import 'package:flutter/material.dart';
import '../models/card_designs.dart';
import '../theme/app_theme.dart';
import 'owl_mascot.dart';
import 'pixel_sprite.dart';
import 'scene_frame.dart';

/// The Player Card cover in a given [design]: the meadow picture with the
/// design's colour wash, pixel decorations (sun, stars, petals…), and an
/// optional plant or kuwago in the corner. Used big on the Profile and
/// small on the design shelf.
class CardCover extends StatelessWidget {
  const CardCover({super.key, required this.design, this.children = const [], this.small = false});

  final CardDesign design;

  /// Extra widgets on top (e.g. the "PLAYER CARD" tag).
  final List<Widget> children;

  /// Shelf thumbnail: smaller decorations.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final tint = design.tint;
    return SceneFrame(
      imageAlignment: const Alignment(0.6, 0.0),
      tint: tint == null ? null : Color(tint),
      golden: design.golden,
      children: [
        if (design.extras.isNotEmpty)
          Positioned.fill(child: CustomPaint(painter: _ExtrasPainter(design.extras, small: small))),
        if (design.sprite != null)
          Positioned(
            left: small ? 2 : 8,
            bottom: small ? -6 : -12,
            child: PixelSprite(design.sprite!, size: small ? 40 : 72, zoom: 1.2),
          ),
        if (design.owl)
          Positioned(
            right: small ? 4 : 12,
            bottom: small ? 0 : 2,
            child: OwlSprite(size: small ? 24 : 48, perch: false),
          ),
        ...children,
      ],
    );
  }
}

/// Pixel decorations, all square "pixels" snapped to a 2 dp grid.
/// Positions come from a fixed seed, so each design always looks the same.
class _ExtrasPainter extends CustomPainter {
  _ExtrasPainter(this.extras, {required this.small});

  final List<CoverExtra> extras;
  final bool small;

  double get px => small ? 1 : AppSizes.artScale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final extra in extras) {
      switch (extra) {
        case CoverExtra.none:
          break;
        case CoverExtra.sun:
          _disc(canvas, Offset(size.width * 0.8, size.height * 0.25), size.height * 0.16, const Color(0xFFFFD24A),
              rim: const Color(0xFFFF9B3D));
        case CoverExtra.moon:
          _disc(canvas, Offset(size.width * 0.82, size.height * 0.24), size.height * 0.13, const Color(0xFFFFF4D6),
              rim: const Color(0xFFD9CFA8));
        case CoverExtra.stars:
          _scatter(canvas, size, 26, 11, const Color(0xFFFFFBEA), topOnly: true, sizePx: 1);
        case CoverExtra.petals:
          _scatter(canvas, size, 22, 5, const Color(0xFFF58DB3), sizePx: 2);
          _scatter(canvas, size, 12, 6, const Color(0xFFFFD0E0), sizePx: 2);
        case CoverExtra.fireflies:
          _scatter(canvas, size, 18, 7, const Color(0xFFE6FF7A), sizePx: 1, glow: true);
        case CoverExtra.sparkles:
          final r = Random(9);
          for (var i = 0; i < 7; i++) {
            _sparkle(canvas, Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.7));
          }
        case CoverExtra.sand:
          // Soft dune bands across the bottom.
          final band = Paint()..color = const Color(0x55E0A860);
          canvas.drawRect(Rect.fromLTWH(0, size.height * 0.78, size.width, px * 3), band);
          canvas.drawRect(Rect.fromLTWH(size.width * 0.2, size.height * 0.88, size.width * 0.8, px * 2), band);
      }
    }
  }

  /// A round pixel disc (sun / moon) with a darker rim.
  void _disc(Canvas canvas, Offset c, double r, Color fill, {required Color rim}) {
    final p = Paint();
    for (var y = -r; y <= r; y += px) {
      final half = sqrt(max(0, r * r - y * y));
      final w = (half / px).floor() * px;
      p.color = (y.abs() > r - px * 2) ? rim : fill;
      canvas.drawRect(Rect.fromLTWH(c.dx - w, c.dy + y, w * 2, px), p);
    }
  }

  void _scatter(Canvas canvas, Size size, int count, int seed, Color color,
      {bool topOnly = false, double sizePx = 1, bool glow = false}) {
    final r = Random(seed);
    final p = Paint()..color = color;
    final halo = Paint()..color = color.withValues(alpha: 0.35);
    for (var i = 0; i < count; i++) {
      final x = (r.nextDouble() * size.width / px).floor() * px;
      final y = (r.nextDouble() * size.height * (topOnly ? 0.5 : 0.85) / px).floor() * px;
      final s = px * sizePx;
      if (glow) canvas.drawRect(Rect.fromLTWH(x - px, y - px, s + px * 2, s + px * 2), halo);
      canvas.drawRect(Rect.fromLTWH(x, y, s, s), p);
    }
  }

  void _sparkle(Canvas canvas, Offset c) {
    final gold = Paint()..color = const Color(0xFFFFE27A);
    final x = (c.dx / px).round() * px, y = (c.dy / px).round() * px;
    canvas.drawRect(Rect.fromLTWH(x - px * 2, y, px * 5, px), gold);
    canvas.drawRect(Rect.fromLTWH(x, y - px * 2, px, px * 5), gold);
    canvas.drawRect(Rect.fromLTWH(x, y, px, px), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ExtrasPainter old) => old.extras != extras || old.small != small;
}
