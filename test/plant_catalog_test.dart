import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/plant_catalog.dart';
import 'package:rooted/widgets/plant_aura.dart';

void main() {
  test('the three top-tier plants exist, in rising rarity, each with an aura', () {
    final phoenix = speciesById('phoenix_bloom');
    final lotus = speciesById('crystal_lotus');
    final glory = speciesById('glory_tree');
    expect([phoenix.rarity, lotus.rarity, glory.rarity], [PlantRarity.legendary, PlantRarity.mythic, PlantRarity.glory]);
    expect([phoenix.aura, lotus.aura, glory.aura], [PlantAura.embers, PlantAura.prism, PlantAura.radiance]);
    expect(speciesById('wild_sunflower').aura, isNull);
  });

  test('plants unlock in catalog order and ids are unique', () {
    final unlocks = plantCatalog.where((s) => s.secret == null).map((s) => s.unlockAtSessions).toList();
    expect(unlocks, [...unlocks]..sort());
    expect(plantCatalog.map((s) => s.id).toSet(), hasLength(plantCatalog.length));
    expect(nextUnlock(30)?.id, 'phoenix_bloom');
    expect(nextUnlock(80)?.id, 'aurora_bell');
    expect(nextUnlock(250), isNull);
  });

  test('the five highest tiers sit above Glory, each with its own seed and aura', () {
    final top = ['aurora_bell', 'storm_orchid', 'starfall_willow', 'dragonheart_rose', 'eternal_sakura'].map(speciesById);
    expect(top.map((s) => s.rarity),
        [PlantRarity.celestial, PlantRarity.astral, PlantRarity.divine, PlantRarity.primordial, PlantRarity.eternal]);
    expect(top.every((s) => s.rarity.index > PlantRarity.glory.index), isTrue);
    expect(top.map((s) => s.aura).toSet(), hasLength(5));
    expect(top.map((s) => s.unlockAtSessions), [100, 125, 150, 200, 250]);
  });

  test('every plant has all its stage, wilted and frame images', () {
    const stages = ['seed', 'sprout', 'grow', 'bloom', 'fullgrown'];
    for (final s in plantCatalog) {
      for (final name in stages) {
        expect(File(s.stageAsset(name)).existsSync(), isTrue, reason: s.stageAsset(name));
        expect(File(s.wiltedAsset(name)).existsSync(), isTrue, reason: s.wiltedAsset(name));
      }
      for (var i = 0; i < 4; i++) {
        final frame = '${s.assetRoot}/frames/${stages[i]}_${stages[i + 1]}_09.png';
        expect(File(frame).existsSync(), isTrue, reason: frame);
      }
    }
  });

  test('the aura grows with the plant and goes out when wilted', () {
    expect(PlantAuraEffect.strengthForStage(0), 0);
    expect(PlantAuraEffect.strengthForStage(2), 0.5);
    expect(PlantAuraEffect.strengthForStage(4), 1);
    expect(PlantAuraEffect.strengthForStage(4, wilted: true), 0);
  });
}
