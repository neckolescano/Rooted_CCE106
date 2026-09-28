import 'dart:math';
import 'package:flutter/material.dart';
import '../models/garden_progress.dart';
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
  const HarvestCelebrationDialog({
    super.key,
    this.plantAsset = 'assets/images/plant/stages/fullgrown.png',
    this.plantName = 'plant',
  });

  /// The grown plant's sprite and name (sunflower, cactus, …).
  final String plantAsset;
  final String plantName;

  static const _frameAsset = 'assets/images/popups/harvest_frame.png';

  // Real size of the scroll art in pixels.
  static const double _artWidth = 144;
  static const double _artHeight = 192;

  // Measured directly from the art's parchment area (the tan region
  // inside the wood border) as fractions of the full frame, so the
  // plant/text land exactly inside it. If you redraw the frame, re-check
  // these against the new parchment bounds.
  static const double _paddingTop = 0.20;
  static const double _paddingBottom = 0.16;
  static const double _paddingLeft = 0.14;
  static const double _paddingRight = 0.14;

  // Space the two buttons need under the scroll.
  static const double _buttonsHeight = AppSizes.buttonHeight * 2 + AppSpacing.md + AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    // BUG FIX: this used to be a Material `Dialog`, which forces a
    // minimum width of 280. That stretched the scroll wider than its
    // height allowed, so the text ran past the parchment ("lives in" got
    // cut off). Now the scroll is sized from the screen itself — 2× the
    // art on normal phones, smaller on tiny ones — and never distorted.
    return PopScope(
      canPop: false, // force an explicit choice instead of a back-swipe
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = min(
                    AppSizes.artScale,
                    min(constraints.maxWidth / _artWidth, (constraints.maxHeight - _buttonsHeight) / _artHeight),
                  );
                  final frameWidth = _artWidth * scale;
                  final frameHeight = _artHeight * scale;

                  return SizedBox(
                    width: max(frameWidth, 240),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: SizedBox(
                            width: frameWidth,
                            height: frameHeight,
                            child: _scroll(frameWidth, frameHeight, scale),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        PixelButton(
                          label: 'Start New Session',
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PixelButton(
                          label: 'Go Home',
                          tone: ButtonTone.secondary,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scroll(double width, double height, double scale) {
    // At 2× this is 128 — the plant's exact pixel size, perfectly crisp.
    final plantSize = 64 * scale;

    return Stack(
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
              color: AppColors.parchment,
              border: Border.all(color: AppColors.panelDark, width: 3),
            ),
          ),
        ),
        // Sits in the open parchment area below the baked-in
        // "CONGRATULATIONS!" banner and above the wooden pegs.
        Padding(
          padding: EdgeInsets.only(
            top: height * _paddingTop,
            left: width * _paddingLeft,
            right: width * _paddingRight,
            bottom: height * _paddingBottom,
          ),
          // Shrinks the whole block if a small phone makes the
          // parchment short, so nothing ever spills out of it.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: width * (1 - _paddingLeft - _paddingRight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SparkleOverlay(
                    size: plantSize + 24,
                    child: Center(
                      child: Image.asset(
                        plantAsset,
                        width: plantSize,
                        height: plantSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        gaplessPlayback: true,
                        semanticLabel: 'Your fully grown plant',
                        errorBuilder: (context, error, stackTrace) =>
                            SizedBox(width: plantSize, height: plantSize),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Dark green, not the light accent green, so it's
                  // readable on the tan parchment.
                  Text(
                    'You did it!',
                    textAlign: TextAlign.center,
                    style: AppText.gameMoment(color: AppColors.greenDeep),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your $plantName is fully grown and now lives in your garden.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(size: 12, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${GardenProgress.xpPerHarvest} GARDEN XP',
                    style: AppTheme.body(size: 12, color: AppColors.panelMedium, weight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
