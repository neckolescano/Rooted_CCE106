/// How rare a plant is. Shown on garden cards.
enum PlantRarity { common, uncommon, rare, legendary, mythic, glory }

/// The moving effect drawn around the top-tier plants (see
/// widgets/plant_aura.dart): rising embers, orbiting crystals, golden rays.
enum PlantAura { embers, prism, radiance }

extension PlantRarityLabel on PlantRarity {
  String get label => switch (this) {
        PlantRarity.common => 'Common',
        PlantRarity.uncommon => 'Uncommon',
        PlantRarity.rare => 'Rare',
        PlantRarity.legendary => 'Legendary',
        PlantRarity.mythic => 'Mythic',
        PlantRarity.glory => 'Glory',
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
    this.aura,
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

  /// A living effect around the plant (legendary and up); null = none.
  final PlantAura? aura;

  String get fullGrownAsset => '$assetRoot/stages/fullgrown.png';
  String stageAsset(String stageName) => '$assetRoot/stages/$stageName.png';

  /// Drooping, dried-out version of a stage (made by tool/generate_plants.dart).
  String wiltedAsset(String stageName) => '$assetRoot/wilted/$stageName.png';
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
  PlantSpecies(
    id: 'phoenix_bloom',
    name: 'Phoenix Bloom',
    category: 'Fire',
    rarity: PlantRarity.legendary,
    unlockAtSessions: 45,
    assetRoot: 'assets/images/plants/phoenix_bloom',
    blurb: 'Blooms into wings of fire. Every give-up, it rises again.',
    aura: PlantAura.embers,
  ),
  PlantSpecies(
    id: 'crystal_lotus',
    name: 'Crystal Lotus',
    category: 'Celestial',
    rarity: PlantRarity.mythic,
    unlockAtSessions: 60,
    assetRoot: 'assets/images/plants/crystal_lotus',
    blurb: 'Crystals drift around it like tiny moons of focus.',
    aura: PlantAura.prism,
  ),
  PlantSpecies(
    id: 'glory_tree',
    name: 'Golden Glory Tree',
    category: 'Eternal',
    rarity: PlantRarity.glory,
    unlockAtSessions: 80,
    assetRoot: 'assets/images/plants/glory_tree',
    blurb: 'A crowned tree of gold for the truest gardeners.',
    aura: PlantAura.radiance,
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
