import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// A little framed window into the game world: your meadow art inside a
/// wooden picture frame, with anything you like layered on top
/// ([children] go in a Stack, so use Positioned).
///
/// Used for the Garden diorama and the Profile cover. When you draw more
/// scene art (garden_bg.png, cottage_bg.png), pass it as [asset].
class SceneFrame extends StatelessWidget {
  const SceneFrame({
    super.key,
    required this.children,
    this.asset = 'assets/images/backgrounds/garden_meadow.png',
    this.imageAlignment = Alignment.center,
  });

  final List<Widget> children;
  final String asset;

  /// Which part of the (tall) meadow picture to show. y = -1 is the sky,
  /// y = 1 is the flowers at the bottom.
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: PanelStyle.wood,
      padding: const EdgeInsets.all(6),
      child: DecoratedBox(
        // Dark inner edge between the frame and the picture.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.panelDark, width: AppBorders.width),
        ),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: imageAlignment,
                // Shown smaller than the source file, so light smoothing
                // looks cleaner than dropped pixels.
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Color(0xFFAFD8C9)),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
