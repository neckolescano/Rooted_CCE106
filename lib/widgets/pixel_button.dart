import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// primary   → plain wood plaque (main actions)
/// secondary → lighter wash (Go Home, Cancel)
/// danger    → reddish wash (Give Up)
enum ButtonTone { primary, secondary, danger }

/// Your hand-drawn wooden plaque button, reused everywhere in the app.
/// The plaque art is a single 96x48 image with flower decoration on
/// both ends — instead of drawing a separate image per button label,
/// this stretches ONLY the plain wood-grain strip in the middle to fit
/// whatever text is on top, so the flower details on the left and
/// right never get distorted, no matter how long the label is.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint,
    this.tone = ButtonTone.primary,
    this.height = AppSizes.buttonHeight,
  });

  final String label;

  /// null = disabled (drawn faded and ignores taps).
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Optional custom color wash over the plaque. Normally just pick a
  /// [tone] instead; this overrides it.
  final Color? tint;
  final ButtonTone tone;
  final double height;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  static const _plaqueAsset = 'assets/images/buttons/button_plaque.png';

  // The plaque is 96px wide. Columns 50–79 are the plain wood-grain gap
  // between the center flower cluster and the right corner flowers —
  // that's the only part that stretches. Everything left of x=50 (both
  // flower clusters on that side) and right of x=79 (the right corner
  // flowers) stays pixel-perfect at its original size.
  // If you redraw the art later with a plainer center, this is the spot
  // to widen for a more even stretch.
  static const _stretchZone = Rect.fromLTRB(50, 0, 79, 48);

  bool _pressed = false;

  Color? get _tint =>
      widget.tint ??
      switch (widget.tone) {
        ButtonTone.primary => null,
        ButtonTone.secondary => AppColors.panelLight,
        ButtonTone.danger => AppColors.danger,
      };

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    Widget plaque = Image.asset(
      _plaqueAsset,
      centerSlice: _stretchZone,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none, // keeps pixel art crisp, no blur
      gaplessPlayback: true,
      // Falls back to a code-drawn box if the art is ever missing.
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.panelMedium,
            border: Border.all(color: AppColors.panelDark, width: AppBorders.width),
          ),
        );
      },
    );

    final tint = _tint;
    if (tint != null) {
      plaque = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
        child: plaque,
      );
    }
    if (_pressed) {
      // Slightly darker while held down — reads as "pushed in".
      plaque = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFFD6D6D6), BlendMode.modulate),
        child: plaque,
      );
    }

    final label = Text(
      widget.label.toUpperCase(),
      maxLines: 1,
      style: AppTheme.body(size: 14, color: AppColors.textCream, weight: FontWeight.w800).copyWith(
        letterSpacing: 0.5,
        // Hard 1-pixel drop shadow (no blur) keeps the label readable on
        // the busy wood grain.
        shadows: const [Shadow(offset: Offset(0, 1.5), color: Color(0x99000000))],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: SizedBox(
            width: double.infinity,
            height: widget.height,
            // The whole button shifts down one art pixel while pressed —
            // a tiny "clack" like a game menu.
            child: Transform.translate(
              offset: Offset(0, _pressed ? AppSizes.artScale : 0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  plaque,
                  // Side padding keeps the text off the flower corners.
                  // FittedBox shrinks long labels instead of overflowing
                  // on small phones.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(widget.icon, color: AppColors.textCream, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            label,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
