import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/plant_display.dart';
import 'timer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// A little rotating encouragement line under the plant, matching the
  /// "Your cozy Fern is craving some focus light!" line in the Figma.
  String _quoteFor(PlantModel plant) {
    if (plant.isWilted) return 'Your plant could use a comeback session.';
    switch (plant.stage) {
      case GrowthStage.seed:
        return 'A tiny seed, waiting for its first session.';
      case GrowthStage.sprout:
        return 'Your cozy sprout is craving some focus light!';
      case GrowthStage.grow:
        return 'It\'s really taking shape — keep it up.';
      case GrowthStage.bloom:
        return 'Almost fully grown — one more push!';
      case GrowthStage.fullGrown:
        return 'Fully grown! Start a new one whenever you\'re ready.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final plant = context.watch<PlantModel>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelPanel(
            backgroundColor: AppColors.panelDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('COZY GREENHOUSE', style: AppTheme.body(size: 13, color: AppColors.textCream, weight: FontWeight.bold)),
                Text('LVL ${plant.level} ${plant.stage.label.toUpperCase()}',
                    style: AppTheme.body(size: 12, color: AppColors.accentGold, weight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: PixelPanel(
              backgroundColor: const Color(0xFFF6DFC0),
              child: Center(child: PlantDisplay(plant: plant, size: 220)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '"${_quoteFor(plant)}"',
            textAlign: TextAlign.center,
            style: AppTheme.body(size: 13, weight: FontWeight.w600),
          ),
          const Spacer(),
          PixelButton(
            label: 'Start Study Session',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TimerScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
