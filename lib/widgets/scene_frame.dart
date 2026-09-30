import 'package:flutter/material.dart';
import '../models/scene_look.dart';
import '../theme/app_theme.dart';
import 'garden_scene_backdrop.dart';
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
    this.tint,
    this.golden = false,
    this.look,
    this.animate = true,
  });

  /// Show this scene look (its own sky, land and moving effects) instead
  /// of [asset] + [tint] — the Garden Archive and Player Cards use this.
  final SceneLook? look;

  /// false = keep the look still (small thumbnails).
  final bool animate;

  final List<Widget> children;
  final String asset;

  /// Which part of the (tall) meadow picture to show. y = -1 is the sky,
  /// y = 1 is the flowers at the bottom.
  final Alignment imageAlignment;

  /// Optional colour wash over the picture (sunset orange, night blue…).
  final Color? tint;

  /// Gold picture frame instead of wood.
  final bool golden;

  @override
  Widget build(BuildContext context) {
    Widget picture = Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: imageAlignment,
      // Shown smaller than the source file, so light smoothing looks
      // cleaner than dropped pixels.
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(color: Color(0xFFAFD8C9)),
    );
    final wash = tint;
    final look = this.look;
    if (look != null) {
      picture = GardenSceneBackdrop(
        look: look,
        animate: animate,
        alignment: imageAlignment,
        pixel: 1.5,
        filterQuality: FilterQuality.medium,
      );
    } else if (wash != null) {
      // "modulate" multiplies the colours: keeps all the pixel detail,
      // just shifts the mood (e.g. blue = night).
      picture = ColorFiltered(colorFilter: ColorFilter.mode(wash, BlendMode.modulate), child: picture);
    }

    return PixelPanel(
      style: PanelStyle.wood,
      backgroundColor: golden ? const Color(0xFFD9A93A) : null,
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
              picture,
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
