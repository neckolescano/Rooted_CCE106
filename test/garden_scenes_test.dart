import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/card_designs.dart' show QuestStats;
import 'package:rooted/models/garden_scenes.dart';
import 'package:rooted/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuestStats stats({int completed = 0, int harvested = 0, int streak = 0, Map<String, int> grown = const {}}) =>
    QuestStats(
      completedSessions: completed,
      harvestedPlants: harvested,
      streak: streak,
      gardenLevel: 1,
      grownBySpecies: grown,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a new gardener has only the starter meadow', () {
    final unlocked = gardenScenes.where((s) => s.isUnlocked(stats())).map((s) => s.id);
    expect(unlocked, ['meadow']);
  });

  test('each scene unlocks from its own quest', () {
    expect(gardenSceneById('sunset').isUnlocked(stats(completed: 3)), isTrue);
    expect(gardenSceneById('sunset').isUnlocked(stats(completed: 2)), isFalse);
    expect(gardenSceneById('cherry').isUnlocked(stats(harvested: 2)), isTrue);
    expect(gardenSceneById('rainy').isUnlocked(stats(completed: 10)), isTrue);
    expect(gardenSceneById('starry').isUnlocked(stats(streak: 4)), isTrue);
    expect(gardenSceneById('starry').isUnlocked(stats(streak: 3)), isFalse);
    expect(gardenSceneById('forest').isUnlocked(stats(grown: {'forest_fern': 1})), isTrue);
    expect(gardenSceneById('forest').isUnlocked(stats(harvested: 5)), isFalse);
    expect(gardenSceneById('autumn').isUnlocked(stats(harvested: 4)), isTrue);
    expect(gardenSceneById('lantern').isUnlocked(stats(streak: 7)), isTrue);
    expect(gardenSceneById('winter').isUnlocked(stats(completed: 30)), isTrue);
    expect(gardenSceneById('aurora').isUnlocked(stats(completed: 49)), isFalse);
    expect(gardenSceneById('aurora').isUnlocked(stats(completed: 50)), isTrue);
  });

  test('there are 12 scenes (one secret); autumn and winter use their own pictures', () {
    expect(gardenScenes, hasLength(12));
    expect(gardenScenes.where((s) => s.secret), hasLength(1));
    expect(gardenSceneById('autumn').asset, contains('autumn'));
    expect(gardenSceneById('winter').asset, contains('winter'));
    expect(gardenSceneById('aurora').effects, contains(SceneEffect.aurora));
    expect(gardenSceneById('meadow').asset, GardenScene.meadowPicture);
  });

  test('quest progress is capped at the goal', () {
    expect(gardenSceneById('rainy').progressLabel(stats(completed: 4)), '4 / 10');
    expect(gardenSceneById('rainy').progressLabel(stats(completed: 25)), '10 / 10');
  });

  test('unknown ids fall back to the meadow; scene ids are unique', () {
    expect(gardenSceneById('nope').id, 'meadow');
    expect(gardenScenes.map((s) => s.id).toSet(), hasLength(gardenScenes.length));
  });

  test('the equipped scene is remembered (meadow by default)', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    expect(storage.gardenScene, 'meadow');
    await storage.setGardenScene('starry');
    expect((await StorageService.create()).gardenScene, 'starry');
  });
}
