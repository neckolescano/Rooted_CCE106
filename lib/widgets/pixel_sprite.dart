import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a piece of pixel art at a given size.
///
/// Pixel art only stays crisp when it's scaled UP. When it's shown
/// smaller than its real size (e.g. a 128px plant in a small garden
/// tile), a little smoothing looks better than dropped pixels — so this
/// picks the right filter automatically.
class PixelSprite extends StatelessWidget {
  const PixelSprite(
    this.asset, {
    super.key,
    required this.size,
    this.artSize = 128,
    this.zoom = 1,
    this.silhouette = false,
    this.fallbackIcon = Icons.local_florist,
    this.semanticLabel,
  });

  final String asset;
  final double size;

  /// The real pixel width of the PNG (plants are 128).
  final double artSize;

  /// Crops in on the drawing. Your plant sprites leave the top third and
  /// bottom fifth of the 128px canvas empty, so in small tiles the plant
  /// looks tiny — zoom: 1.5 fills the tile with the actual plant.
  final double zoom;

  /// Draws the sprite as a solid dark shape — used for locked plants.
  final bool silhouette;
  final IconData fallbackIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: size * zoom >= artSize ? FilterQuality.none : FilterQuality.medium,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: size,
        height: size,
        child: Icon(fallbackIcon, color: AppColors.panelDark, size: size * 0.45),
      ),
    );

    if (zoom != 1) {
      // Scale around the plant's middle (about 56% down the canvas).
      image = ClipRect(
        child: Transform.scale(scale: zoom, alignment: const Alignment(0, 0.12), child: image),
      );
    }

    if (!silhouette) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xCC3E2A1B), BlendMode.srcIn),
      child: image,
    );
  }
}
