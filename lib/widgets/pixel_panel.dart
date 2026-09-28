import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The three looks every box in the app uses:
///   wood      → brown cards (settings rows, garden cards)
///   dark      → dark plank bars (headers, chips, the timer slot)
///   parchment → light paper (journal page, plant scene, dialogs)
enum PanelStyle { wood, dark, parchment }

/// The 4 colors a pixel frame is drawn with: a dark outline, the fill,
/// a light top/left edge and a darker bottom/right edge. That lit-edge +
/// shadow-edge trick is what makes your plaque button and harvest scroll
/// look "carved", so every code-drawn panel copies it.
class PixelFrameColors {
  const PixelFrameColors({
    required this.outline,
    required this.fill,
    required this.light,
    required this.shade,
  });

  final Color outline;
  final Color fill;
  final Color light;
  final Color shade;

  static const wood = PixelFrameColors(
    outline: AppColors.panelDark,
    fill: AppColors.panelMedium,
    light: AppColors.panelLight,
    shade: Color(0xFF6B4226),
  );

  static const dark = PixelFrameColors(
    outline: Color(0xFF1E140C),
    fill: AppColors.panelDark,
    light: Color(0xFF5B3E28),
    shade: Color(0xFF2B1D12),
  );

  static const parchment = PixelFrameColors(
    outline: AppColors.panelDark,
    fill: AppColors.parchment,
    light: Color(0xFFFFF4E0),
    shade: AppColors.parchmentShade,
  );

  static PixelFrameColors of(PanelStyle style, {Color? fill, Color? outline}) {
    final base = switch (style) {
      PanelStyle.wood => wood,
      PanelStyle.dark => dark,
      PanelStyle.parchment => parchment,
    };
    return PixelFrameColors(
      outline: outline ?? base.outline,
      fill: fill ?? base.fill,
      light: base.light,
      shade: base.shade,
    );
  }
}

/// The bordered box used everywhere — header bars, the plant scene,
/// settings rows, the journal page. One widget, three styles, so every
/// screen gets the exact same border, corners and shading.
///
/// When you draw 9-slice panel art later (panel_wood.png etc.), only
/// this file needs to change to use it.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.style = PanelStyle.wood,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.sunken = false,
    this.shadow = true,
    this.backgroundColor,
    this.outlineColor,
    this.expand = true,
  });

  final Widget child;
  final PanelStyle style;
  final EdgeInsets padding;

  /// Flips the light/dark edges so the box looks pressed IN instead of
  /// raised — used for slots like the timer display and garden plots.
  final bool sunken;

  /// A 1-art-pixel hard shadow under the box (no blur — blur isn't pixel art).
  final bool shadow;

  /// Optional override for the fill, e.g. a see-through dark panel over
  /// the meadow. The edges keep the style's colors.
  final Color? backgroundColor;

  /// Optional override for the outline, e.g. gold for a selected nav slot.
  final Color? outlineColor;

  /// true = stretch to full width (the old PixelPanel behavior),
  /// false = shrink to fit the child (chips, small badges).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final panel = CustomPaint(
      painter: PixelFramePainter(
        colors: PixelFrameColors.of(style, fill: backgroundColor, outline: outlineColor),
        sunken: sunken,
        shadow: shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
    return expand ? SizedBox(width: double.infinity, child: panel) : panel;
  }
}

/// A tiny grey nail head, like the ones on your harvest scroll. Put four
/// in the corners of a wooden sign (Stack + Positioned).
class PixelNail extends StatelessWidget {
  const PixelNail({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      color: const Color(0xFFB8B0A6),
      alignment: Alignment.bottomRight,
      child: Container(width: 2, height: 2, color: const Color(0xFF6E665E)),
    );
  }
}

/// Paints a pixel-art box: 1-pixel outline with the corner pixels cut
/// off (that's what makes corners look "rounded" in pixel art), a fill,
/// then a light top/left edge and a dark bottom/right edge.
/// One art pixel = [AppSizes.artScale] dp, same as all the drawn art.
class PixelFramePainter extends CustomPainter {
  PixelFramePainter({required this.colors, this.sunken = false, this.shadow = true});

  final PixelFrameColors colors;
  final bool sunken;
  final bool shadow;

  static const double px = AppSizes.artScale;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    if (outer.width < px * 3 || outer.height < px * 3) return;

    if (shadow) {
      canvas.drawRect(
        Rect.fromLTRB(outer.left + px, outer.bottom, outer.right - px, outer.bottom + px),
        Paint()..color = const Color(0x40000000),
      );
    }

    // Outline as 4 edges (not one filled shape), so a see-through fill
    // doesn't show a dark rectangle behind it.
    final line = Paint()..color = colors.outline;
    canvas.drawRect(Rect.fromLTRB(outer.left + px, outer.top, outer.right - px, outer.top + px), line);
    canvas.drawRect(Rect.fromLTRB(outer.left + px, outer.bottom - px, outer.right - px, outer.bottom), line);
    canvas.drawRect(Rect.fromLTRB(outer.left, outer.top + px, outer.left + px, outer.bottom - px), line);
    canvas.drawRect(Rect.fromLTRB(outer.right - px, outer.top + px, outer.right, outer.bottom - px), line);

    final inner = outer.deflate(px);
    canvas.drawRect(inner, Paint()..color = colors.fill);

    if (inner.width > px * 2 && inner.height > px * 2) {
      final topLeft = Paint()..color = sunken ? colors.shade : colors.light;
      final bottomRight = Paint()..color = sunken ? colors.light : colors.shade;
      canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width, px), topLeft);
      canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, px, inner.height), topLeft);
      canvas.drawRect(Rect.fromLTWH(inner.left, inner.bottom - px, inner.width, px), bottomRight);
      canvas.drawRect(Rect.fromLTWH(inner.right - px, inner.top, px, inner.height), bottomRight);
    }
  }

  @override
  bool shouldRepaint(PixelFramePainter old) =>
      old.colors.fill != colors.fill ||
      old.colors.outline != colors.outline ||
      old.sunken != sunken ||
      old.shadow != shadow;
}
