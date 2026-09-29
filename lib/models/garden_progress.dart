import 'plant_model.dart';

/// Garden level + XP, worked out from the saved counters
/// (StorageService.completedSessions / harvestedPlants). Nothing here is
/// stored — it's recalculated every time, so tuning the numbers below
/// instantly re-levels everyone.
class GardenProgress {
  const GardenProgress({required this.completedSessions, required this.harvestedPlants});

  /// Only for accounts from before the real counter existed: every
  /// completed session grows the plant one stage and a harvest takes 4,
  /// so completed ≈ harvested × 4 + current stage. Used ONCE to seed the
  /// counter (see StorageService), never for display.
  static int estimateCompleted({required int harvestedPlants, required int plantStageIndex}) {
    final stagesPerPlant = GrowthStage.values.length - 1; // seed → grown = 4 steps
    return harvestedPlants * stagesPerPlant + plantStageIndex;
  }

  // ---- Tuning knobs — change these to make leveling faster/slower ----
  static const xpPerSession = 10;
  static const xpPerHarvest = 50;
  static const xpPerLevel = 100;

  final int completedSessions;
  final int harvestedPlants;

  int get xp => completedSessions * xpPerSession + harvestedPlants * xpPerHarvest;
  int get level => 1 + xp ~/ xpPerLevel;
  int get xpIntoLevel => xp % xpPerLevel;
  double get levelProgress => xpIntoLevel / xpPerLevel;
}
