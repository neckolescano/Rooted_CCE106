import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'sparkle_overlay.dart';

/// Shown once a plant hits its final growth stage. Uses the hand-drawn
/// wooden scroll/frame art — its "CONGRATULATIONS!" banner is already
/// baked into the image, so this widget just places the fully-grown
/// plant (with a little sparkle flourish) and a short message inside
/// the open parchment area, then the two choice buttons below it.
///
/// The two buttons are what actually matter to keep: they return `true`
/// (start a new session right away) or `false` (just go back home) to
/// whoever called showDialog, so the logic underneath doesn't need to
/// change even if this art changes again later.
class HarvestCelebrationDialog extends StatelessWidget {
  const HarvestCelebrationDialog({super.key});

  static const _fullyGrownAsset = 'assets/images/plant/stages/fullgrown.png';
  static const _frameAsset = 'assets/images/popups/harvest_frame.png';

  // Source art is 144x192 (a 3:4 ratio). Scaling the whole frame up
  // from that keeps the pixel art crisp without needing to draw more
  // detail than will actually be visible on screen.
  static const double _frameWidth = 240;
  static const double _frameHeight = _frameWidth * 192 / 144;

  // Measured directly from the art's parchment area (the tan region
  // inside the wood border) as fractions of the full frame, so the
  // plant/text land exactly inside it. If you redraw the frame, re-check
  // these against the new parchment bounds.
  static const double _paddingTop = 0.20;
  static const double _paddingBottom = 0.16;
  static const double _paddingLeft = 0.12;
  static const double _paddingRight = 0.13;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // force an explicit choice instead of a back-swipe
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: SizedBox(
          width: _frameWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _frameHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      _frameAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      // Falls back to a plain card if the art isn't in
                      // the project yet, so nothing breaks.
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.panelDark, width: 3),
                        ),
                      ),
                    ),
                    // Sits in the open parchment area below the baked-in
                    // "CONGRATULATIONS!" banner and above the wooden
                    // pegs at the bottom.
                    Padding(
                      padding: EdgeInsets.only(
                        top: _frameHeight * _paddingTop,
                        left: _frameWidth * _paddingLeft,
                        right: _frameWidth * _paddingRight,
                        bottom: _frameHeight * _paddingBottom,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SparkleOverlay(
                            size: 130,
                            child: Center(
                              child: Image.asset(
                                _fullyGrownAsset,
                                width: 104,
                                height: 104,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                gaplessPlayback: true,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(width: 104, height: 104),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You did it!',
                            textAlign: TextAlign.center,
                            style: AppTheme.pixelHeading(size: 11, color: AppColors.accentGreen),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your plant is fully grown and now lives in your garden.',
                            textAlign: TextAlign.center,
                            style: AppTheme.body(size: 11, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PixelButton(
                label: 'Start New Session',
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 12),
              PixelButton(
                label: 'Go Home',
                tint: AppColors.panelLight,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
