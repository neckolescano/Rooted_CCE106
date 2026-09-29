import 'dart:math';
import 'card_designs.dart' show QuestStats;

/// Moving pixel effects drawn over a scene (see widgets/garden_scene_backdrop.dart).
enum SceneEffect { sun, moon, stars, petals, rain, fireflies, leaves }

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
    this.tint,
    this.effects = const [],
  });

  final String id;
  final String name;
  final String emoji;

  /// What to do to unlock it, e.g. "Finish 3 focus sessions."
  final String quest;

  /// Current progress toward [goal].
  final int Function(QuestStats) progressOf;
  final int goal;

  /// Colour wash over the meadow picture (null = the normal meadow).
  /// Multiplied in, so all the pixel detail stays.
  final int? tint;
  final List<SceneEffect> effects;

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
  ),
  GardenScene(
    id: 'sunset',
    name: 'Golden Sunset',
    emoji: '🌇',
    quest: 'Finish 3 focus sessions.',
    progressOf: (s) => s.completedSessions,
    goal: 3,
    tint: 0xFFFFB27A,
    effects: [SceneEffect.sun],
  ),
  GardenScene(
    id: 'cherry',
    name: 'Cherry Blossom',
    emoji: '🌸',
    quest: 'Grow 2 plants.',
    progressOf: (s) => s.harvestedPlants,
    goal: 2,
    tint: 0xFFFFD6E4,
    effects: [SceneEffect.petals],
  ),
  GardenScene(
    id: 'rainy',
    name: 'Rainy Day',
    emoji: '🌧️',
    quest: 'Finish 10 focus sessions.',
    progressOf: (s) => s.completedSessions,
    goal: 10,
    tint: 0xFF8497A8, // grey-blue: an overcast, rainy day
    effects: [SceneEffect.rain],
  ),
  GardenScene(
    id: 'starry',
    name: 'Starry Night',
    emoji: '🌙',
    quest: 'Finish 4 focus sessions in a row.',
    progressOf: (s) => s.streak,
    goal: 4,
    tint: 0xFF3E4C8C,
    effects: [SceneEffect.stars, SceneEffect.moon, SceneEffect.fireflies],
  ),
  GardenScene(
    id: 'forest',
    name: 'Firefly Forest',
    emoji: '✨',
    quest: 'Grow a Forest Fern.',
    progressOf: (s) => s.grown('forest_fern'),
    goal: 1,
    tint: 0xFF6E9A66,
    effects: [SceneEffect.fireflies, SceneEffect.leaves],
  ),
];

/// Looks up a scene; unknown ids fall back to the starter meadow.
GardenScene gardenSceneById(String? id) =>
    gardenScenes.firstWhere((s) => s.id == id, orElse: () => gardenScenes.first);
