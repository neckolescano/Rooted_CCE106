import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Your hand-drawn wooden plaque button, reused everywhere in the app.
/// The plaque art is a single 96x48 image with flower decoration on
/// both ends — instead of drawing a separate image per button label,
/// this stretches ONLY the plain wood-grain strip in the middle to fit
/// whatever text is on top, so the flower details on the left and
/// right never get distorted, no matter how long the label is.
class PixelButton extends StatelessWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint,
    this.height = 52,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  /// Optional color wash over the plaque — e.g. a reddish tint for a
  /// "danger" button like Give Up — while keeping the wood texture
  /// visible underneath (as opposed to a flat solid color).
  final Color? tint;

  final double height;

  static const _plaqueAsset = 'assets/images/buttons/button_plaque.png';

  // The plaque is 96px wide. Columns 50–79 are the plain wood-grain gap
  // between the center flower cluster and the right corner flowers —
  // that's the only part that stretches. Everything left of x=50 (both
  // flower clusters on that side) and right of x=79 (the right corner
  // flowers) stays pixel-perfect at its original size.
  // If you redraw the art later with a plainer center, this is the spot
  // to widen for a more even stretch.
  static const _stretchZone = Rect.fromLTRB(50, 0, 79, 48);

  @override
  Widget build(BuildContext context) {
    Widget plaque = Image.asset(
      _plaqueAsset,
      centerSlice: _stretchZone,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none, // keeps pixel art crisp, no blur
      gaplessPlayback: true,
      // Falls back to the old flat rectangle if the art isn't in the
      // project yet, so nothing breaks while art is still in progress.
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.panelMedium,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.panelDark, width: 2),
          ),
        );
      },
    );

    if (tint != null) {
      plaque = ColorFiltered(
        colorFilter: ColorFilter.mode(tint!, BlendMode.modulate),
        child: plaque,
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            fit: StackFit.expand,
            children: [
              plaque,
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: AppColors.textCream, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label.toUpperCase(),
                      style: AppTheme.body(
                        size: 14,
                        color: AppColors.textCream,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
