import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';
import 'plant_aura.dart';

/// Shows the plant's current pixel-art image — the drooping "wilted" art
/// after a session was given up. If a PNG is ever missing, this shows a
/// simple placeholder instead of crashing.
class PlantDisplay extends StatelessWidget {
  const PlantDisplay({super.key, required this.plant, this.size = 140});

  final PlantModel plant;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Legendary+ plants glow, burn or sparkle — more as they grow.
    return PlantAuraEffect(
      aura: plant.species.aura,
      strength: PlantAuraEffect.strengthForStage(plant.stage.index, wilted: plant.isWilted),
      child: _art(context),
    );
  }

  Widget _art(BuildContext context) {
    final normal = _sprite(plant.assetPath, fallback: _placeholder);
    if (!plant.isWilted) return normal;

    // Real wilted art (tool/generate_plants.dart makes it). If that file
    // isn't there, fall back to a dulled-down copy of the normal sprite.
    return _sprite(
      plant.wiltedAssetPath,
      fallback: (context) => ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.55, 0.30, 0.10, 0, 0,
          0.45, 0.35, 0.10, 0, 0,
          0.30, 0.25, 0.10, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: normal,
      ),
    );
  }

  Widget _sprite(String path, {required WidgetBuilder fallback}) {
    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none, // keeps pixel art crisp, no blur
      gaplessPlayback: true, // no blank flash when switching stage images
      errorBuilder: (context, error, stackTrace) => fallback(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.panelLight.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.panelDark, width: AppBorders.width),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_florist, color: AppColors.panelDark, size: 36),
          const SizedBox(height: 4),
          Text(
            plant.stage.label,
            textAlign: TextAlign.center,
            style: AppTheme.body(size: 11, color: AppColors.panelDark),
          ),
        ],
      ),
    );
  }
}
