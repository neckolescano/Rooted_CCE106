import 'plant_model.dart';

/// Garden level + XP, worked out from numbers the app already saves.
/// Nothing here is stored — it's recalculated every time, so tuning the
/// numbers below instantly re-levels everyone.
///
/// TEMPORARY SHORTCUT: the app doesn't save a "completed sessions" count
/// yet (totalSessions also counts given-up ones). But every completed
/// session grows the plant exactly one stage, and each harvested plant
/// took 4 stages, so:
///     completed = harvested × 4 + current stage
/// The garden progression phase replaces this with a real saved counter.
class GardenProgress {
  const GardenProgress({required this.completedSessions, required this.harvestedPlants});

  factory GardenProgress.from({required int harvestedPlants, required int plantStageIndex}) {
    final stagesPerPlant = GrowthStage.values.length - 1; // seed → grown = 4 steps
    return GardenProgress(
      completedSessions: harvestedPlants * stagesPerPlant + plantStageIndex,
      harvestedPlants: harvestedPlants,
    );
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
