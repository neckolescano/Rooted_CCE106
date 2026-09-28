import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A wooden desk top drawn in code: brown planks with dark seams and a
/// lit edge. The Journal and Study Material screens sit on it so they
/// feel like a gardener's desk instead of a plain notes app.
///
/// When you draw desk_bg.png later, swap the CustomPaint for an image.
class DeskBackground extends StatelessWidget {
  const DeskBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DeskPainter(), child: child);
  }
}

class _DeskPainter extends CustomPainter {
  static const double px = AppSizes.artScale;
  static const double plankHeight = 64;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.panelMedium);

    final seam = Paint()..color = const Color(0xFF6B4226);
    final lit = Paint()..color = const Color(0xFF9A6840);
    final grain = Paint()..color = const Color(0xFF81522F);

    var row = 0;
    for (var y = 0.0; y < size.height; y += plankHeight, row++) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, px), seam);
      canvas.drawRect(Rect.fromLTWH(0, y + px, size.width, px), lit);
      // A couple of short grain streaks per plank, offset every other
      // row so it doesn't look like a grid.
      final shift = row.isEven ? 0.0 : size.width * 0.35;
      for (final x in [0.12, 0.55, 0.85]) {
        final left = (size.width * x + shift) % size.width;
        canvas.drawRect(Rect.fromLTWH(left, y + plankHeight * 0.45, size.width * 0.12, px), grain);
      }
      // Vertical plank joint, alternating sides.
      final jointX = row.isEven ? size.width * 0.68 : size.width * 0.3;
      canvas.drawRect(Rect.fromLTWH(jointX, y + px * 2, px, plankHeight - px * 2), seam);
    }
  }

  @override
  bool shouldRepaint(_DeskPainter old) => false;
}
