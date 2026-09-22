import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_panel.dart';

/// A single plant species the student has unlocked, e.g. "Wild Sunflower".
/// This is a simple placeholder model for now — later this can be swapped
/// for real saved data (which species + how many of each the student has
/// actually grown), but the UI underneath won't need to change.
class _UnlockedPlant {
  const _UnlockedPlant(this.name, this.count);
  final String name;
  final int count;
}

const _fullyGrownAsset = 'assets/images/plant/stages/fullgrown.png';

// Species variety (different plant types, not just repeats of the same
// one) isn't built yet — this list is still placeholder data. The row
// below it, though, is real: one tile per plant the student has
// actually harvested.
const _placeholderUnlocked = [
  _UnlockedPlant('Wild Sunflower', 2),
  _UnlockedPlant('Desert Cactus', 1),
];

class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          PixelPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GARDEN ARCHIVE', style: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Streak: ${storage.streak} days', style: AppTheme.body(size: 12, color: AppColors.accentGold)),
                    Text('Total: ${storage.totalSessions} sessions', style: AppTheme.body(size: 12, color: AppColors.accentGold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Grown: ${storage.harvestedPlants} plants', style: AppTheme.body(size: 12, color: AppColors.accentGold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('FULLY-GROWN PLANTED ROW', style: AppTheme.body(size: 13, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          PixelPanel(
            backgroundColor: const Color(0xFFF6DFC0),
            child: Column(
              children: [
                if (storage.harvestedPlants == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No fully-grown plants yet — finish a whole session\n'
                      'to add your first one here!',
                      textAlign: TextAlign.center,
                      style: AppTheme.body(size: 12, color: AppColors.panelDark),
                    ),
                  )
                else
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      // One real tile per plant the student has actually
                      // harvested — same sprite each time for now, since
                      // there's only the one plant/species so far.
                      itemCount: storage.harvestedPlants,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.panelLight.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.panelDark, width: 1.5),
                              ),
                              child: Image.asset(
                                _fullyGrownAsset,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.local_florist, color: AppColors.panelDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('#${index + 1}', style: AppTheme.body(size: 9)),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Text('COZY MEADOW BED', style: AppTheme.body(size: 11, color: AppColors.accentGreen, weight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._placeholderUnlocked.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final plant = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PixelPanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$i. ${plant.name.toUpperCase()}',
                        style: AppTheme.body(size: 12, color: AppColors.textCream, weight: FontWeight.bold)),
                    Text('Unlocked x${plant.count}',
                        style: AppTheme.body(size: 12, color: AppColors.accentGold, weight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
