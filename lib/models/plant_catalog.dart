/// How rare a plant is. Shown on garden cards.
enum PlantRarity { common, uncommon, rare, legendary }

extension PlantRarityLabel on PlantRarity {
  String get label => switch (this) {
        PlantRarity.common => 'Common',
        PlantRarity.uncommon => 'Uncommon',
        PlantRarity.rare => 'Rare',
        PlantRarity.legendary => 'Legendary',
      };
}

/// One kind of plant the student can collect.
class PlantSpecies {
  const PlantSpecies({
    required this.id,
    required this.name,
    required this.category,
    required this.rarity,
    required this.unlockAtSessions,
    required this.assetRoot,
    required this.blurb,
  });

  final String id;
  final String name;

  /// Meadow, Forest, Desert, Tropical, Flower, Herb, Magical, Seasonal
  final String category;
  final PlantRarity rarity;

  /// Completed focus sessions needed before this plant can be planted.
  final int unlockAtSessions;

  /// Folder holding this plant's art, laid out like the sunflower's:
  ///   <assetRoot>/stages/seed.png … fullgrown.png
  ///   <assetRoot>/frames/seed_sprout_00.png … bloom_fullgrown_09.png
  final String assetRoot;

  /// One cozy line shown when picking a seed.
  final String blurb;

  String get fullGrownAsset => '$assetRoot/stages/fullgrown.png';
  String stageAsset(String stageName) => '$assetRoot/stages/$stageName.png';
}

/// Every plant in the game, in unlock order.
///
/// TO ADD A PLANT: put its art in assets/images/plants/<id>/ (same file
/// names as the sunflower — or add it to tool/generate_plants.dart),
/// list both folders in pubspec.yaml, then add a line here.
const plantCatalog = <PlantSpecies>[
  PlantSpecies(
    id: 'wild_sunflower',
    name: 'Wild Sunflower',
    category: 'Meadow',
    rarity: PlantRarity.common,
    unlockAtSessions: 0,
    assetRoot: 'assets/images/plant', // your original hand-drawn art
    blurb: 'A sunny meadow classic. Always happy to see you.',
  ),
  PlantSpecies(
    id: 'desert_cactus',
    name: 'Desert Cactus',
    category: 'Desert',
    rarity: PlantRarity.uncommon,
    unlockAtSessions: 10,
    assetRoot: 'assets/images/plants/desert_cactus',
    blurb: 'Tough, patient, and blooms pink when it is proud of you.',
  ),
  PlantSpecies(
    id: 'forest_fern',
    name: 'Forest Fern',
    category: 'Forest',
    rarity: PlantRarity.uncommon,
    unlockAtSessions: 20,
    assetRoot: 'assets/images/plants/forest_fern',
    blurb: 'Unfurls one frond at a time, just like good study habits.',
  ),
  PlantSpecies(
    id: 'moonpetal_lily',
    name: 'Moonpetal Lily',
    category: 'Magical',
    rarity: PlantRarity.rare,
    unlockAtSessions: 30,
    assetRoot: 'assets/images/plants/moonpetal_lily',
    blurb: 'Said to glow for gardeners who never give up.',
  ),
];

/// The plant everyone starts with.
PlantSpecies get starterSpecies => plantCatalog.first;

/// Looks up a plant by id. Unknown ids (e.g. old saves) fall back to the
/// starter plant instead of crashing.
PlantSpecies speciesById(String? id) {
  for (final species in plantCatalog) {
    if (species.id == id) return species;
  }
  return starterSpecies;
}

bool isUnlocked(PlantSpecies species, int completedSessions) => completedSessions >= species.unlockAtSessions;

/// The next plant that isn't unlocked yet, or null if everything is.
PlantSpecies? nextUnlock(int completedSessions) {
  for (final species in plantCatalog) {
    if (completedSessions < species.unlockAtSessions) return species;
  }
  return null;
}
