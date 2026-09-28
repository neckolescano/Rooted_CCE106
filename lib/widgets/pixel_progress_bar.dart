import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A chunky pixel progress bar. Two modes:
///   * continuous (segments == null) — XP, session time
///   * segmented  (segments: 5)      — the 5 plant growth stages
class PixelProgressBar extends StatelessWidget {
  const PixelProgressBar({
    super.key,
    required this.value,
    this.segments,
    this.height = 16,
    this.fillColor = AppColors.accentGreen,
    this.semanticLabel,
  });

  /// 0.0 to 1.0
  final double value;
  final int? segments;
  final double height;
  final Color fillColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()} percent',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarPainter(value: clamped, segments: segments, fill: fillColor),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.value, required this.segments, required this.fill});

  final double value;
  final int? segments;
  final Color fill;

  static const double px = AppSizes.artScale;
  static const _outline = AppColors.panelDark;
  static const _track = Color(0xFF2B1D12);
  static const _emptySegment = Color(0xFF5B3E28);

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final line = Paint()..color = _outline;
    // Outline with cut corners, same as PixelPanel.
    canvas.drawRect(Rect.fromLTRB(outer.left + px, outer.top, outer.right - px, outer.top + px), line);
    canvas.drawRect(Rect.fromLTRB(outer.left + px, outer.bottom - px, outer.right - px, outer.bottom), line);
    canvas.drawRect(Rect.fromLTRB(outer.left, outer.top + px, outer.left + px, outer.bottom - px), line);
    canvas.drawRect(Rect.fromLTRB(outer.right - px, outer.top + px, outer.right, outer.bottom - px), line);

    final inner = outer.deflate(px);
    final count = segments;

    if (count == null) {
      canvas.drawRect(inner, Paint()..color = _track);
      if (value > 0) _paintFill(canvas, Rect.fromLTWH(inner.left, inner.top, inner.width * value, inner.height));
      return;
    }

    // Segmented: dark gaps between chunks, like a game health bar.
    canvas.drawRect(inner, Paint()..color = _outline);
    final segWidth = (inner.width - px * (count - 1)) / count;
    final filled = (value * count).round();
    for (var i = 0; i < count; i++) {
      final rect = Rect.fromLTWH(inner.left + i * (segWidth + px), inner.top, segWidth, inner.height);
      if (i < filled) {
        _paintFill(canvas, rect);
      } else {
        canvas.drawRect(rect, Paint()..color = _emptySegment);
      }
    }
  }

  /// Fill with a lighter top pixel and darker bottom pixel for a bit of shine.
  void _paintFill(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = fill);
    if (rect.height > px * 3) {
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, px), Paint()..color = Color.lerp(fill, Colors.white, 0.35)!);
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.bottom - px, rect.width, px), Paint()..color = Color.lerp(fill, Colors.black, 0.25)!);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.value != value || old.segments != segments || old.fill != fill;
}
