import 'package:flutter/material.dart';
import '../models/plant_catalog.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_dialog.dart';
import 'pixel_panel.dart';
import 'pixel_sprite.dart';

/// Opens the "Choose a seed" scroll. Returns the picked plant id, or null
/// if the student closed it without choosing.
Future<String?> showSeedPicker(
  BuildContext context, {
  required String currentId,
  required int completedSessions,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: AppColors.overlay,
    builder: (dialogContext) => PixelDialog(
      title: 'Choose a seed',
      sealIcon: Icons.spa,
      body: Column(
        children: [
          for (final species in plantCatalog) ...[
            _SeedOption(
              species: species,
              selected: species.id == currentId,
              unlocked: isUnlocked(species, completedSessions),
              onTap: () => Navigator.of(dialogContext).pop(species.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
      actions: [
        PixelButton(
          label: 'Keep this seed',
          tone: ButtonTone.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// One seed packet row: sprite (or lock), name, and a line of flavour
/// text — or how many sessions until it unlocks.
class _SeedOption extends StatelessWidget {
  const _SeedOption({
    required this.species,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final PlantSpecies species;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = unlocked ? AppColors.textDark : AppColors.textCream;

    return Semantics(
      button: unlocked,
      selected: selected,
      label: unlocked
          ? '${species.name}${selected ? ', planted now' : ''}'
          : '${species.name}, locked, unlocks at ${species.unlockAtSessions} focus sessions',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: unlocked ? onTap : null,
        child: PixelPanel(
          style: unlocked ? PanelStyle.parchment : PanelStyle.dark,
          outlineColor: selected ? AppColors.accentGold : null,
          backgroundColor: selected ? const Color(0xFFFBEBC6) : null,
          shadow: false,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: PixelPanel(
                  style: unlocked ? PanelStyle.parchment : PanelStyle.dark,
                  sunken: true,
                  shadow: false,
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: unlocked
                        ? PixelSprite(species.fullGrownAsset, size: 46, zoom: 1.5)
                        : const Icon(Icons.lock, size: 20, color: AppColors.accentGold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unlocked ? species.name : '??? · ${species.category}',
                      style: AppTheme.body(size: 14, color: textColor, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unlocked ? species.blurb : 'Unlocks at ${species.unlockAtSessions} focus sessions',
                      style: AppText.caption(color: unlocked ? AppColors.textMuted : AppColors.accentGold),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check_circle, size: 20, color: AppColors.greenDeep),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
