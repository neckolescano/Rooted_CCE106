// The secret seed and scene: hidden until their achievement is found.
import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/card_designs.dart' show QuestStats;
import 'package:rooted/models/garden_scenes.dart';
import 'package:rooted/models/plant_catalog.dart';
import 'package:rooted/models/secrets.dart';
import 'package:rooted/models/session_model.dart';
import 'package:rooted/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

QuestStats stats({Set<String> secrets = const {}}) => QuestStats(
      completedSessions: 999,
      harvestedPlants: 999,
      streak: 999,
      gardenLevel: 99,
      grownBySpecies: const {},
      secrets: secrets,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the secret seed ignores session counts and needs the perfect-patch secret', () {
    final owl = speciesById('owlbloom');
    expect(owl.rarity, PlantRarity.secret);
    expect(isUnlocked(owl, 100000), isFalse);
    expect(isUnlocked(owl, 0, secrets: {Secrets.perfectPatch}), isTrue);
    expect(owl.hint, isNotEmpty);
    // It is never offered as the "next quest".
    expect(nextUnlock(0)?.id, isNot('owlbloom'));
  });

  test('the secret scene stays locked however much you study, until deep focus is found', () {
    final grove = gardenSceneById('owl_grove');
    expect(grove.secret, isTrue);
    expect(grove.isUnlocked(stats()), isFalse);
    expect(grove.isUnlocked(stats(secrets: {Secrets.deepFocus})), isTrue);
  });

  test('a secret is celebrated only the first time and is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    expect(await storage.unlockSecret(Secrets.deepFocus), isTrue);
    expect(await storage.unlockSecret(Secrets.deepFocus), isFalse);
    expect((await StorageService.create()).secrets, contains(Secrets.deepFocus));
  });

  test('deep focus needs a long enough session and no pause', () {
    const needed = Secrets.deepFocusMinutes;
    final long = SessionModel()..start(minutes: needed);
    expect(long.wasDeepFocus, isTrue);
    long.pause();
    long.resume();
    expect(long.wasDeepFocus, isFalse, reason: 'paused once');
    long.start(minutes: needed);
    expect(long.wasDeepFocus, isTrue, reason: 'a new session starts fresh');
    long.reset();
    if (needed > 1) {
      final short = SessionModel()..start(minutes: needed - 1);
      expect(short.wasDeepFocus, isFalse);
      short.reset();
    }
  });
}
