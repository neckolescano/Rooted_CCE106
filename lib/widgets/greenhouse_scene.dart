import 'dart:math';
import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';
import '../services/intro_cue.dart';
import 'owl_mascot.dart';
import 'pixel_panel.dart';
import 'plant_display.dart';
import 'window_zoom.dart';

/// The Home screen's "greenhouse": a cottage wall with a big window
/// looking out onto your meadow art, and your plant in a wooden planter
/// on the windowsill. Everything except the meadow and plant is drawn in
/// code, so it works today with no new art.
///
/// The window has two hinged halves. When Start Study Session is pressed,
/// [WindowZoom] swings them open and the plant ducks into its planter,
/// then the camera flies out through the middle.
///
/// Later, when you draw greenhouse_bg / greenhouse_mid / greenhouse_fg,
/// they replace the code-drawn wall and window here.
class GreenhouseScene extends StatelessWidget {
  const GreenhouseScene({super.key, required this.plant, this.windowKey, this.owlMessages});

  final PlantModel plant;

  /// If given, kuwago the owl stands on the windowsill next to the plant
  /// and says these (in order) when tapped.
  final List<String>? owlMessages;

  /// Put on the window so the Home screen can find where it is on screen
  /// (the Start Study Session zoom flies into it).
  final GlobalKey? windowKey;

  static const _meadowAsset = 'assets/images/backgrounds/garden_meadow.png';

  // Sizes the scene can show the 128px plant at. 256 = exactly 2×
  // (the art-scale rule). Smaller phones fall back to the next size.
  static const _plantSizes = [256.0, 192.0, 160.0, 128.0, 96.0];

  static const double _sillHeight = 12;
  static const double _planterHeight = 26;
  static const double _wallBelowSill = 18;

  /// How far the window halves swing open, in radians (~100°).
  static const double _maxSwing = 1.75;

  @override
  Widget build(BuildContext context) {
    // 0 = closed, 1 = fully open. Comes from WindowZoom when there is one.
    final Animation<double> open = WindowZoom.maybeOf(context)?.windowOpen ?? kAlwaysDismissedAnimation;

    return PixelPanel(
      style: PanelStyle.parchment,
      padding: const EdgeInsets.all(4), // just the frame edge
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            final sillTop = h - _wallBelowSill - _sillHeight;
            final windowRect = Rect.fromLTRB(w * 0.1, 14, w * 0.9, sillTop);

            // Biggest plant that fits between the window top and the sill.
            // (The top ~30% of each sprite is empty sky, so it's fine
            // for that part to overlap the window frame.)
            final roomForPlant = sillTop - _planterHeight - 10;
            final plantSize = _plantSizes.firstWhere(
              (s) => s * 0.7 <= roomForPlant && s <= w * 0.85,
              orElse: () => 80,
            );

            final planterWidth = plantSize * 0.6;
            final planterTop = sillTop - _planterHeight + 4;
            // Your plant sprites end at row 103 of 128 — the last ~19%
            // is empty. Push the sprite down by that much, plus a little
            // extra so the soil mound sinks into the planter.
            final plantBottom = planterTop + plantSize * 0.22;
            final plantTop = plantBottom - plantSize;

            // kuwago stands on the sill to the right of the planter
            // (72 dp = 3× the 24-px art; 48 on small phones).
            final owlSize = plantSize >= 160 ? 72.0 : 48.0;
            final owlLeft = max((w + planterWidth) / 2 + 2, windowRect.right - owlSize + 8);
            // The owl's feet are at 21/24 of its height — stand them on the sill.
            final owlTop = sillTop - owlSize * 21 / 24 + 1;
            // The plant is cut off just below the planter's top edge, so
            // when it ducks down it disappears INTO the planter instead of
            // showing through underneath it.
            final plantClipBottom = planterTop + 6;

            return AnimatedBuilder(
              animation: open,
              builder: (context, _) {
                // The plant ducks first, the window swings a beat later.
                final duck = Curves.easeInBack.transform((open.value / 0.6).clamp(0.0, 1.0));
                final swing = Curves.easeInOutCubic.transform(((open.value - 0.2) / 0.8).clamp(0.0, 1.0));

                return Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _WallPainter())),
                    // The window: meadow art, the casing, then the two
                    // hinged halves on top.
                    Positioned.fromRect(
                      rect: windowRect,
                      child: Stack(
                        key: windowKey,
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            _meadowAsset,
                            fit: BoxFit.cover,
                            // Aimed at the horizon + tree. Shown smaller than
                            // the source, so light smoothing looks cleaner.
                            alignment: const Alignment(0.2, 0.1),
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(color: Color(0xFFAFD8C9)),
                          ),
                          CustomPaint(painter: _CasingPainter()),
                          _Sash(isLeft: true, angle: swing * _maxSwing),
                          _Sash(isLeft: false, angle: swing * _maxSwing),
                        ],
                      ),
                    ),
                    // Windowsill plank.
                    Positioned(
                      left: windowRect.left - 10,
                      right: w - windowRect.right - 10,
                      top: sillTop,
                      height: _sillHeight,
                      child: const PixelPanel(style: PanelStyle.wood, padding: EdgeInsets.zero, child: SizedBox.expand()),
                    ),
                    // The plant (drawn BEFORE the planter so the planter's
                    // front edge covers the bottom of the soil).
                    Positioned(
                      left: (w - plantSize) / 2,
                      top: plantTop,
                      width: plantSize,
                      height: plantClipBottom - plantTop,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: plantSize,
                          child: Transform.translate(
                            offset: Offset(0, duck * plantSize * 0.8),
                            child: PlantDisplay(plant: plant, size: plantSize),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (w - planterWidth) / 2,
                      top: planterTop,
                      width: planterWidth,
                      height: _planterHeight,
                      child: const _Planter(),
                    ),
                    if (owlMessages != null)
                      Positioned(
                        left: owlLeft,
                        top: owlTop,
                        width: owlSize,
                        height: owlSize,
                        // On app start the opening flies kuwago in to this
                        // exact spot, so it stays hidden until it lands.
                        child: KeyedSubtree(
                          key: IntroCue.homeOwlKey,
                          child: ValueListenableBuilder<IntroStage>(
                            valueListenable: IntroCue.stage,
                            builder: (context, stage, child) =>
                                Opacity(opacity: stage == IntroStage.done ? 1 : 0, child: child),
                            child: OwlMascot(
                              size: owlSize,
                              perch: false,
                              wander: true,
                              floatingBubble: true,
                              messages: owlMessages!,
                              // Cheers as the window swings open for a session.
                              cheering: open.value > 0.01,
                              cheerLine: "Let's go!",
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// One half of the window, hinged on its outer edge. [angle] 0 = closed.
class _Sash extends StatelessWidget {
  const _Sash({required this.isLeft, required this.angle});

  final bool isLeft;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      widthFactor: 0.5,
      heightFactor: 1,
      child: Transform(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        // setEntry(3, 2, ...) adds perspective, so the swinging half looks
        // like it's coming toward you instead of just getting thinner.
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..multiply(Matrix4.rotationY(isLeft ? angle : -angle)),
        child: CustomPaint(painter: _SashPainter(isLeft: isLeft)),
      ),
    );
  }
}

/// Wooden planter box: a wood panel with one darker plank seam.
class _Planter extends StatelessWidget {
  const _Planter();

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: PanelStyle.wood,
      backgroundColor: const Color(0xFF7A4A2B),
      padding: EdgeInsets.zero,
      child: Center(
        child: Container(
          height: AppSizes.artScale,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: const Color(0xFF5A351E),
        ),
      ),
    );
  }
}

/// Parchment wall with faint horizontal plank lines, so it reads as a
/// cottage wall instead of a blank box.
class _WallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final seam = Paint()..color = AppColors.parchmentShade.withValues(alpha: 0.7);
    const plankHeight = 22.0;
    for (var y = plankHeight; y < size.height; y += plankHeight) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, AppSizes.artScale), seam);
    }
  }

  @override
  bool shouldRepaint(_WallPainter old) => false;
}

// Shared wood-bar drawing for the casing and the sashes.
const double _px = AppSizes.artScale;
final _outline = Paint()..color = AppColors.panelDark;
final _wood = Paint()..color = AppColors.panelMedium;
final _woodLight = Paint()..color = AppColors.panelLight;
final _woodShade = Paint()..color = const Color(0xFF6B4226);

/// A wooden bar: dark outline, lit top edge, shaded bottom edge.
void _drawBar(Canvas canvas, Rect r) {
  canvas.drawRect(r, _outline);
  final inner = r.deflate(_px);
  if (inner.isEmpty) return;
  canvas.drawRect(inner, _wood);
  canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width, _px), _woodLight);
  canvas.drawRect(Rect.fromLTWH(inner.left, inner.bottom - _px, inner.width, _px), _woodShade);
}

/// The fixed frame around the window opening (stays put when the halves
/// swing open).
class _CasingPainter extends CustomPainter {
  static const double thickness = 4;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBar(canvas, Rect.fromLTWH(0, 0, size.width, thickness));
    _drawBar(canvas, Rect.fromLTWH(0, 0, thickness, size.height));
    _drawBar(canvas, Rect.fromLTWH(size.width - thickness, 0, thickness, size.height));
  }

  @override
  bool shouldRepaint(_CasingPainter old) => false;
}

/// One window half: frame, cross-bar, and a glint on the upper glass.
/// Glass itself is left see-through so the meadow shows.
class _SashPainter extends CustomPainter {
  _SashPainter({required this.isLeft});

  final bool isLeft;

  static const double frame = 7; // top, bottom and hinge side
  static const double stile = 4; // the side where the two halves meet
  static const double bar = 6; // horizontal cross-bar

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final barY = h * 0.45;

    // Glint on the upper pane (drawn first; the frame covers its ends).
    final paneLeft = isLeft ? frame : stile;
    final paneRight = isLeft ? w - stile : w - frame;
    final paneW = paneRight - paneLeft;
    final glint = Path()
      ..moveTo(paneLeft + paneW * 0.15, barY)
      ..lineTo(paneLeft + paneW * 0.32, barY)
      ..lineTo(paneLeft + paneW * 0.78, frame)
      ..lineTo(paneLeft + paneW * 0.61, frame)
      ..close();
    canvas.drawPath(glint, Paint()..color = Colors.white.withValues(alpha: 0.28));

    _drawBar(canvas, Rect.fromLTWH(0, 0, w, frame));
    _drawBar(canvas, Rect.fromLTWH(0, h - frame, w, frame));
    _drawBar(canvas, Rect.fromLTWH(isLeft ? 0 : w - frame, 0, frame, h)); // hinge side
    _drawBar(canvas, Rect.fromLTWH(isLeft ? w - stile : 0, 0, stile, h)); // meeting side
    _drawBar(canvas, Rect.fromLTWH(0, barY - bar / 2, w, bar));

    // A tiny brass handle on the meeting side.
    final handleX = isLeft ? w - stile - 5 : stile + 1;
    canvas.drawRect(Rect.fromLTWH(handleX, barY + bar, 4, 8), _outline);
    canvas.drawRect(Rect.fromLTWH(handleX + 1, barY + bar + 1, 2, 6), Paint()..color = AppColors.accentGold);
  }

  @override
  bool shouldRepaint(_SashPainter old) => old.isLeft != isLeft;
}
