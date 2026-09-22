import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';

/// Shows the plant's current pixel-art image. If you haven't dropped the
/// matching PNG into assets/images/plant/ yet, this shows a simple
/// placeholder instead of crashing — so you can build screens before
/// all the art is finished.
class PlantDisplay extends StatelessWidget {
  const PlantDisplay({super.key, required this.plant, this.size = 140});

  final PlantModel plant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      plant.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none, // keeps pixel art crisp, no blur
      gaplessPlayback: true, // no blank flash when switching stage images
      // Falls back to a plain placeholder box if a path is ever wrong —
      // shouldn't happen now that the real art is in, but keeps things
      // from crashing if a file goes missing.
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.panelLight.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.panelDark, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_florist, color: AppColors.panelDark, size: 36),
              const SizedBox(height: 4),
              Text(
                plant.stage.label,
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 10, color: AppColors.panelDark),
              ),
            ],
          ),
        );
      },
    );

    if (!plant.isWilted) return image;

    // No separate "wilted" art was drawn, so instead of asking for more
    // sprites we just desaturate + darken the normal sprite in place.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.35, 0.35, 0.35, 0, -20,
        0.35, 0.35, 0.35, 0, -20,
        0.30, 0.30, 0.30, 0, -20,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }
}
