import 'dart:math';
import 'card_designs.dart' show QuestStats;
import 'scene_look.dart';
import 'secrets.dart';

export 'scene_look.dart';

/// One Garden Scene: the world outside — shown behind the Timer, in the
/// Garden Archive picture and through the Home greenhouse window. Unlocked
/// by a quest (like the Player Card designs), then equipped on the Garden
/// page.
class GardenScene {
  const GardenScene({
    required this.id,
    required this.name,
    required this.emoji,
    required this.quest,
    required this.progressOf,
    required this.goal,
    required this.look,
    this.secret = false,
    this.hint,
  });

  static const meadowPicture = SceneLooks.meadowLand;

  final String id;
  final String name;
  final String emoji;

  /// What to do to unlock it, e.g. "Finish 3 focus sessions."
  final String quest;

  /// Current progress toward [goal].
  final int Function(QuestStats) progressOf;
  final int goal;

  /// Its sky, land picture and moving effects (see models/scene_look.dart).
  final SceneLook look;

  String get asset => look.land;
  List<SceneEffect> get effects => look.effects;

  /// A secret scene hides its name and picture until it is found; only
  /// [hint] is shown (see models/secrets.dart).
  final bool secret;
  final String? hint;

  bool isUnlocked(QuestStats s) => progressOf(s) >= goal;
  double progress(QuestStats s) => goal == 0 ? 1 : min(1, progressOf(s) / goal);
  String progressLabel(QuestStats s) => '${min(progressOf(s), goal)} / $goal';
}

const defaultGardenScene = 'meadow';

/// Every scene, in the order shown on the Garden page. To add one: add an
/// entry here (and, for a new kind of effect, a SceneEffect + its drawing).
final List<GardenScene> gardenScenes = [
  GardenScene(
    id: 'meadow',
    name: 'Morning Meadow',
    emoji: '🌿',
    quest: 'Your starter scene.',
    progressOf: (_) => 1,
    goal: 1,
    look: SceneLooks.meadow,
  ),
  GardenScene(
    id: 'sunset',
    name: 'Golden Sunset',
    emoji: '🌇',
    quest: 'Finish 3 focus sessions.',
    progressOf: (s) => s.completedSessions,
    goal: 3,
    look: SceneLooks.sunset,
  ),
  GardenScene(
    id: 'cherry',
    name: 'Cherry Blossom',
    emoji: '🌸',
    quest: 'Grow 2 plants.',
    progressOf: (s) => s.harvestedPlants,
    goal: 2,
    look: SceneLooks.cherry,
  ),
  GardenScene(
    id: 'rainy',
    name: 'Rainy Day',
    emoji: '🌧️',
    quest: 'Finish 10 focus sessions.',
    progressOf: (s) => s.completedSessions,
    goal: 10,
    look: SceneLooks.rainy,
  ),
  GardenScene(
    id: 'starry',
    name: 'Starry Night',
    emoji: '🌙',
    quest: 'Finish 4 focus sessions in a row.',
    progressOf: (s) => s.streak,
    goal: 4,
    look: SceneLooks.starry,
  ),
  GardenScene(
    id: 'forest',
    name: 'Firefly Forest',
    emoji: '✨',
    quest: 'Grow a Forest Fern.',
    progressOf: (s) => s.grown('forest_fern'),
    goal: 1,
    look: SceneLooks.forest,
  ),
  GardenScene(
    id: 'autumn',
    name: 'Autumn Harvest',
    emoji: '🍂',
    quest: 'Grow 4 plants.',
    progressOf: (s) => s.harvestedPlants,
    goal: 4,
    look: SceneLooks.autumn,
  ),
  GardenScene(
    id: 'rainbow',
    name: 'Rainbow Morning',
    emoji: '🌈',
    quest: 'Reach garden level 5.',
    progressOf: (s) => s.gardenLevel,
    goal: 5,
    look: SceneLooks.rainbow,
  ),
  GardenScene(
    id: 'lantern',
    name: 'Lantern Night',
    emoji: '🏮',
    quest: 'Finish 7 focus sessions in a row.',
    progressOf: (s) => s.streak,
    goal: 7,
    look: SceneLooks.lantern,
  ),
  GardenScene(
    id: 'winter',
    name: 'Winter Wonderland',
    emoji: '❄️',
    quest: 'Finish 30 focus sessions.',
    progressOf: (s) => s.completedSessions,
    goal: 30,
    look: SceneLooks.winter,
  ),
  GardenScene(
    id: 'aurora',
    name: 'Aurora Borealis',
    emoji: '🌌',
    quest: 'Finish 50 focus sessions.',
    progressOf: (s) => s.completedSessions,
    goal: 50,
    look: SceneLooks.aurora,
  ),
  // The secret scene: kuwago's hidden home.
  GardenScene(
    id: 'owl_grove',
    name: 'Hidden Owl Grove',
    emoji: '🦉',
    quest: 'Finish a focus session of 60 minutes or more without pausing.',
    progressOf: (s) => s.secrets.contains(Secrets.deepFocus) ? 1 : 0,
    goal: 1,
    look: SceneLooks.owlGrove,
    secret: true,
    hint: 'kuwago whispers: "Stay one whole hour without a single pause."',
  ),
];

/// Looks up a scene; unknown ids fall back to the starter meadow.
GardenScene gardenSceneById(String? id) =>
    gardenScenes.firstWhere((s) => s.id == id, orElse: () => gardenScenes.first);
