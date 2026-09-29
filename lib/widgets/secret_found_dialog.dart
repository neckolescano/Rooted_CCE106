import 'package:flutter/material.dart';
import '../models/garden_scenes.dart';
import '../models/plant_catalog.dart';
import '../theme/app_theme.dart';
import 'garden_scene_backdrop.dart';
import 'pixel_dialog.dart';
import 'pixel_sprite.dart';
import 'plant_aura.dart';

/// "A secret sprouted!" — shown once, the moment a secret seed is found.
Future<void> showSecretSeedFound(BuildContext context, PlantSpecies species) {
  return _show(
    context,
    art: PlantAuraEffect(aura: species.aura, child: PixelSprite(species.fullGrownAsset, size: 128)),
    name: species.name,
    message: 'You answered every question right on the first try. '
        'kuwago shares its own flower with you. Plant it from the seed picker!',
  );
}

/// "A secret sprouted!" — shown once, the moment the secret scene is found.
Future<void> showSecretSceneFound(BuildContext context, GardenScene scene) {
  return _show(
    context,
    art: SizedBox(
      width: 220,
      height: 120,
      child: ClipRect(child: GardenSceneBackdrop(scene: scene, alignment: const Alignment(0.3, 0.2), pixel: 1.5)),
    ),
    name: scene.name,
    message: 'A whole hour without a single pause! kuwago shows you its hidden home. '
        'Equip it from Garden Scenes on the Garden page.',
  );
}

Future<void> _show(BuildContext context, {required Widget art, required String name, required String message}) {
  return showPixelMessage(
    context,
    title: 'A secret sprouted!',
    sealIcon: Icons.auto_awesome,
    buttonLabel: 'Hoo-ray!',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        art,
        const SizedBox(height: AppSpacing.sm),
        Text(name.toUpperCase(), textAlign: TextAlign.center, style: AppTheme.pixelHeading(size: 11, color: AppColors.textDark)),
        const SizedBox(height: AppSpacing.xs),
        Text(message, textAlign: TextAlign.center, style: AppText.body()),
      ],
    ),
  );
}
