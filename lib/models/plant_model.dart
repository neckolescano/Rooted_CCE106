import 'package:flutter/material.dart';

/// The 5 growth stages from your Chapter 1 doc.
/// Order matters here — index 0 is youngest, index 4 is fully grown.
enum GrowthStage { seed, sprout, grow, bloom, fullGrown }

extension GrowthStageLabel on GrowthStage {
  /// Text shown on screen, e.g. "SPROUT"
  String get label {
    switch (this) {
      case GrowthStage.seed:
        return 'Seed';
      case GrowthStage.sprout:
        return 'Sprout';
      case GrowthStage.grow:
        return 'Grow';
      case GrowthStage.bloom:
        return 'Bloom';
      case GrowthStage.fullGrown:
        return 'Full Grown';
    }
  }

  /// File name (without extension) this stage maps to in assets/images/plant/
  String get assetName {
    switch (this) {
      case GrowthStage.seed:
        return 'seed';
      case GrowthStage.sprout:
        return 'sprout';
      case GrowthStage.grow:
        return 'grow';
      case GrowthStage.bloom:
        return 'bloom';
      case GrowthStage.fullGrown:
        return 'fullgrown';
    }
  }
}

/// Tracks the plant's current stage and whether it's healthy or wilted.
/// Wraps it in ChangeNotifier so any screen listening to this rebuilds
/// automatically the moment the plant changes.
class PlantModel extends ChangeNotifier {
  GrowthStage stage = GrowthStage.seed;
  bool isWilted = false;

  /// Level shown in the UI, e.g. "LVL 4 SPROUT" — just the stage index + 1.
  int get level => stage.index + 1;

  /// The current stage's still image, e.g. assets/images/plant/stages/grow.png
  /// There's no separate "wilted" art file — PlantDisplay applies a
  /// grey/brown tint on top of this same image when isWilted is true,
  /// so one sprite per stage is all that's needed.
  String get assetPath => 'assets/images/plant/stages/${stage.assetName}.png';

  bool get isFullyGrown => stage == GrowthStage.fullGrown;

  /// e.g. "seed_sprout" — matches the frame file prefix in
  /// assets/images/plant/frames/. Null once the plant is fully grown,
  /// since there's nowhere further to grow into.
  String? get transitionKeyToNextStage {
    if (stage.index >= GrowthStage.values.length - 1) return null;
    final next = GrowthStage.values[stage.index + 1];
    return '${stage.assetName}_${next.assetName}';
  }

  /// The 10 frame paths for a given transition key, in play order.
  static List<String> framePathsFor(String transitionKey) {
    return List.generate(
      10,
      (i) => 'assets/images/plant/frames/${transitionKey}_0$i.png',
    );
  }

  /// Called when a study session finishes successfully.
  void grow() {
    isWilted = false;
    if (stage.index < GrowthStage.values.length - 1) {
      stage = GrowthStage.values[stage.index + 1];
    }
    notifyListeners();
  }

  /// Called when a session is abandoned or the timer runs out unfinished.
  /// Per the design: this is a static swap, not an animation.
  void wilt() {
    isWilted = true;
    notifyListeners();
  }

  /// Starts a brand new plant from a seed (e.g. after fully growing one
  /// and starting the next one in the garden).
  void resetToSeed() {
    stage = GrowthStage.seed;
    isWilted = false;
    notifyListeners();
  }

  /// Restore saved progress (used by StorageService on app start).
  void loadFrom({required int stageIndex, required bool wilted}) {
    stage = GrowthStage.values[stageIndex.clamp(0, GrowthStage.values.length - 1)];
    isWilted = wilted;
    notifyListeners();
  }
}
