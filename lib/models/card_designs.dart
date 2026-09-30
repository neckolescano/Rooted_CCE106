import 'dart:math';
import 'scene_look.dart';

/// The numbers quests are checked against (all already tracked by the app).
class QuestStats {
  const QuestStats({
    required this.completedSessions,
    required this.harvestedPlants,
    required this.streak,
    required this.gardenLevel,
    required this.grownBySpecies,
    this.secrets = const {},
  });

  final int completedSessions;
  final int harvestedPlants;
  final int streak;
  final int gardenLevel;

  /// How many of each plant have been grown, e.g. {'desert_cactus': 2}.
  final Map<String, int> grownBySpecies;

  /// Hidden achievements found (see models/secrets.dart).
  final Set<String> secrets;

  int grown(String speciesId) => grownBySpecies[speciesId] ?? 0;
}

/// One Player Card design: how it looks + the quest that unlocks it.
class CardDesign {
  const CardDesign({
    required this.id,
    required this.name,
    required this.quest,
    required this.progressOf,
    required this.goal,
    required this.look,
    this.sprite,
    this.owl = false,
    this.golden = false,
  });

  final String id;
  final String name;

  /// What to do to unlock it, e.g. "Finish 5 focus sessions".
  final String quest;

  /// Current progress toward [goal] (e.g. sessions finished so far).
  final int Function(QuestStats) progressOf;
  final int goal;

  /// The picture behind the card: sky, land and moving effects
  /// (the same looks as the Garden Scenes — see models/scene_look.dart).
  final SceneLook look;

  /// Optional plant sprite standing in the corner of the cover.
  final String? sprite;

  /// kuwago the owl sits on the cover.
  final bool owl;

  /// Gold picture frame instead of wood.
  final bool golden;

  bool isUnlocked(QuestStats s) => progressOf(s) >= goal;
  double progress(QuestStats s) => goal == 0 ? 1 : min(1, progressOf(s) / goal);
  String progressLabel(QuestStats s) => '${min(progressOf(s), goal)} / $goal';
}

const defaultCardDesign = 'meadow';

/// Every design, in the order shown on the Profile shelf.
/// To add one: add an entry here (and, for a new look, a SceneLook in
/// models/scene_look.dart).
final List<CardDesign> cardDesigns = [
  CardDesign(
    id: 'meadow',
    name: 'Meadow',
    quest: 'Your starter card.',
    progressOf: (_) => 1,
    goal: 1,
    look: SceneLooks.meadow,
  ),
  CardDesign(
    id: 'sunset',
    name: 'Sunset Field',
    quest: 'Finish 5 focus sessions.',
    progressOf: (s) => s.completedSessions,
    goal: 5,
    look: SceneLooks.sunset,
  ),
  CardDesign(
    id: 'cherry',
    name: 'Cherry Blossom',
    quest: 'Grow 3 plants.',
    progressOf: (s) => s.harvestedPlants,
    goal: 3,
    look: SceneLooks.cherry,
  ),
  CardDesign(
    id: 'starry',
    name: 'Starry Night',
    quest: 'Get 5 focus sessions in a row.',
    progressOf: (s) => s.streak,
    goal: 5,
    look: SceneLooks.starry,
  ),
  CardDesign(
    id: 'desert',
    name: 'Desert Dunes',
    quest: 'Grow a Desert Cactus.',
    progressOf: (s) => s.grown('desert_cactus'),
    goal: 1,
    look: SceneLooks.desert,
    sprite: 'assets/images/plants/desert_cactus/stages/fullgrown.png',
  ),
  CardDesign(
    id: 'forest',
    name: 'Enchanted Forest',
    quest: 'Grow a Forest Fern.',
    progressOf: (s) => s.grown('forest_fern'),
    goal: 1,
    look: SceneLooks.forest,
    sprite: 'assets/images/plants/forest_fern/stages/fullgrown.png',
  ),
  CardDesign(
    id: 'moonlit',
    name: 'Moonlit Garden',
    quest: 'Grow a Moonpetal Lily.',
    progressOf: (s) => s.grown('moonpetal_lily'),
    goal: 1,
    look: SceneLooks.moonlit,
    sprite: 'assets/images/plants/moonpetal_lily/stages/fullgrown.png',
  ),
  CardDesign(
    id: 'golden',
    name: 'Golden Scholar',
    quest: 'Reach garden level 5.',
    progressOf: (s) => s.gardenLevel,
    goal: 5,
    look: SceneLooks.golden,
    owl: true,
    golden: true,
  ),
];

/// Looks up a design; unknown ids fall back to the starter Meadow.
CardDesign cardDesignById(String? id) =>
    cardDesigns.firstWhere((d) => d.id == id, orElse: () => cardDesigns.first);
