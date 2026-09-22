import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';

/// Shown once a plant hits its final growth stage. Uses the hand-drawn
/// wooden scroll/frame art — its "CONGRATULATIONS!" banner is already
/// baked into the image, so this widget just places the fully-grown
/// plant and a short message inside the open parchment area, then the
/// two choice buttons below it.
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
                    // pegs at the bottom. Nudge these fractions if the
                    // art changes and this stops lining up.
                    Padding(
                      padding: EdgeInsets.only(
                        top: _frameHeight * 0.28,
                        left: _frameWidth * 0.16,
                        right: _frameWidth * 0.16,
                        bottom: _frameHeight * 0.14,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            _fullyGrownAsset,
                            width: 88,
                            height: 88,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(width: 88, height: 88),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Fully grown! Added to your garden.',
                            textAlign: TextAlign.center,
                            style: AppTheme.body(size: 11, weight: FontWeight.w700),
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
