/// The five growth stages a plant moves through, one per completed
/// Pomodoro session. This mirrors the design in the Chapter 1 doc:
/// seed -> sprout -> grow -> bloom -> fullGrown.
enum PlantStage { seed, sprout, grow, bloom, fullGrown }

extension PlantStageLabel on PlantStage {
  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case PlantStage.seed:
        return 'Seed';
      case PlantStage.sprout:
        return 'Sprout';
      case PlantStage.grow:
        return 'Growing';
      case PlantStage.bloom:
        return 'Blooming';
      case PlantStage.fullGrown:
        return 'Full Grown';
    }
  }

  /// File-name-safe key used to build the asset path, e.g. "seed", "fullGrown".
  String get assetKey => toString().split('.').last;
}

/// Tracks the plant's current growth stage and whether it's currently
/// wilted. This is deliberately a plain class (no Flutter imports) so
/// it's easy to unit test on its own.
class PlantState {
  PlantStage stage;
  bool isWilted;

  PlantState({this.stage = PlantStage.seed, this.isWilted = false});

  bool get isFullyGrown => stage == PlantStage.fullGrown;

  /// Called when a Pomodoro session is completed successfully.
  /// Advances the plant one stage (or keeps it at fullGrown) and
  /// clears any wilted state.
  void grow() {
    isWilted = false;
    final nextIndex = stage.index + 1;
    if (nextIndex < PlantStage.values.length) {
      stage = PlantStage.values[nextIndex];
    }
  }

  /// Called when a session is abandoned or fails. Per the design doc,
  /// this is a static swap to the wilted version of the *current*
  /// stage — not a stage regression, and not animated.
  void wilt() {
    isWilted = true;
  }

  /// Resets the plant back to a fresh seed. Useful for "start a new
  /// plant" once one reaches fullGrown, or for manual resets.
  void resetToSeed() {
    stage = PlantStage.seed;
    isWilted = false;
  }

  /// Builds the asset path this state should render, following the
  /// naming convention: assets/plant/<stage>.png or
  /// assets/plant/<stage>_wilted.png. See README.md for the full list.
  String get assetPath {
    final suffix = isWilted ? '_wilted' : '';
    return 'assets/plant/${stage.assetKey}$suffix.png';
  }
}
