import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garden_progress.dart';
import '../models/plant_catalog.dart';
import '../models/plant_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pixel_dialog.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/pixel_progress_bar.dart';
import '../widgets/pixel_section_header.dart';
import '../widgets/pixel_sprite.dart';
import '../widgets/plant_display.dart';
import '../widgets/scene_frame.dart';

/// The Garden: a little framed meadow where your grown plants actually
/// stand (behind a picket fence), a quest card for the next unlock, and
/// your plant collection as cards on a shelf.
class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final plant = context.watch<PlantModel>();
    final progress = GardenProgress.from(
      harvestedPlants: storage.harvestedPlants,
      plantStageIndex: plant.stage.index,
    );
    final found = plantCatalog.where((s) => isUnlocked(s, progress.completedSessions)).length;
    // Which plant each harvest was, oldest first.
    final log = storage.harvestLog;

    return ListView(
      padding: AppSpacing.screen,
      children: [
        SizedBox(
          height: 310,
          child: _GardenDiorama(progress: progress, harvestLog: log, plant: plant),
        ),
        const SizedBox(height: AppSpacing.sm),
        _StatsLedger(
          streak: storage.streak,
          sessions: storage.totalSessions,
          grown: storage.harvestedPlants,
        ),
        const SizedBox(height: AppSpacing.xl),
        const PixelSectionHeader('Next quest'),
        _QuestCard(completedSessions: progress.completedSessions),
        const SizedBox(height: AppSpacing.xl),
        PixelSectionHeader(
          'Seed collection',
          trailing: Text('$found / ${plantCatalog.length} found', style: AppText.small(color: AppColors.textMuted)),
        ),
        _CollectionShelf(
          completedSessions: progress.completedSessions,
          harvestLog: log,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Diorama: meadow + hanging sign + soil bed + plants + picket fence
// ---------------------------------------------------------------------------

class _GardenDiorama extends StatelessWidget {
  const _GardenDiorama({required this.progress, required this.harvestLog, required this.plant});

  final GardenProgress progress;
  final List<String> harvestLog; // plant id per harvest, oldest first
  final PlantModel plant;

  int get harvested => harvestLog.length;

  // Plant sprites shown at 120 dp; each next plant stands 64 dp further
  // right, so neighbours overlap a little like a real flower bed.
  static const double _plantSize = 120;
  static const double _step = 64;
  static const double _soilLine = 40; // soil surface, measured from the bottom
  static const double _fenceHeight = 30;
  static const double _stakeRoom = 76; // gap after the growing plant for its stake
  static const double _edge = 12; // space at both ends of the bed
  static const double _bedHeight = 160;

  @override
  Widget build(BuildContext context) {
    return SceneFrame(
      // Horizon about halfway down: sky behind the sign, grass behind the bed.
      imageAlignment: const Alignment(0.5, 0.4),
      children: [
        Positioned(top: 0, left: 0, right: 0, child: Center(child: _HangingSign(progress: progress))),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _bedHeight,
          child: LayoutBuilder(builder: (context, c) => _bed(c.maxWidth)),
        ),
      ],
    );
  }

  /// One long soil bed that scrolls sideways (like the seed shelf): the
  /// growing plant first, then every grown plant #1, #2, #3...
  /// The sky and sign above stay still while the bed slides.
  Widget _bed(double viewWidth) {
    const firstHarvestX = _edge + _step + _stakeRoom;
    final neededWidth = harvested == 0
        ? _edge + _plantSize + _stakeRoom + _edge
        : firstHarvestX + _step * (harvested - 1) + _plantSize + _edge;
    final contentWidth = math.max(viewWidth, neededWidth);
    final overflows = contentWidth > viewWidth + 1;

    // Sprites end at row 103 of 128 (see greenhouse_scene.dart), so push
    // them down by that empty strip to stand the soil on the bed.
    const plantBottom = _soilLine - _plantSize * 0.19;

    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: _bedHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _soilLine + 4,
                  child: CustomPaint(painter: _SoilPainter()),
                ),
                // The plant you're growing right now, with a garden stake.
                Positioned(
                  left: _edge,
                  bottom: plantBottom,
                  width: _plantSize,
                  height: _plantSize,
                  child: PlantDisplay(plant: plant, size: _plantSize),
                ),
                const Positioned(
                  left: _edge + _plantSize - 22,
                  bottom: _soilLine - 8,
                  child: _GardenStake(label: 'GROWING'),
                ),
                for (var i = 0; i < harvested; i++)
                  Positioned(
                    left: firstHarvestX + _step * i,
                    bottom: plantBottom,
                    width: _plantSize,
                    height: _plantSize,
                    child: _HarvestedPlant(
                      number: i + 1,
                      species: speciesById(harvestLog[i]),
                      size: _plantSize,
                    ),
                  ),
                // Picket fence in front, as long as the whole bed.
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _fenceHeight,
                  child: CustomPaint(painter: _FencePainter()),
                ),
              ],
            ),
          ),
        ),
        if (overflows)
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: PixelPanel(
                style: PanelStyle.dark,
                expand: false,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Swipe to see all $harvested', style: AppText.caption(color: AppColors.accentGold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 12, color: AppColors.accentGold),
                  ],
                ),
              ),
            ),
          ),
        if (harvested == 0)
          Positioned(
            left: 8,
            top: 8,
            child: PixelPanel(
              style: PanelStyle.parchment,
              expand: false,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Text('Grow a plant to fill your bed!', style: AppText.caption(color: AppColors.textDark)),
            ),
          ),
      ],
    );
  }
}

/// "GARDEN ARCHIVE" sign hanging from two ropes, with the level + XP bar.
class _HangingSign extends StatelessWidget {
  const _HangingSign({required this.progress});

  final GardenProgress progress;

  static const _shadow = [Shadow(offset: Offset(0, 2), color: Color(0x99000000))];

  @override
  Widget build(BuildContext context) {
    Widget rope() => Container(width: 3, height: 16, color: const Color(0xFF4A3322));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [rope(), const SizedBox(width: 150), rope()],
        ),
        Stack(
          children: [
            PixelPanel(
              style: PanelStyle.wood,
              expand: false,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: SizedBox(
                width: 196,
                child: Column(
                  children: [
                    Text(
                      'GARDEN ARCHIVE',
                      style: AppTheme.pixelHeading(size: 11, color: AppColors.textCream).copyWith(shadows: _shadow),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'LV ${progress.level}',
                          style: AppTheme.pixelHeading(size: 10, color: AppColors.accentGold).copyWith(shadows: _shadow),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: PixelProgressBar(
                            value: progress.levelProgress,
                            height: 12,
                            fillColor: AppColors.accentGold,
                            semanticLabel: 'Garden experience',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${progress.xpIntoLevel} / ${GardenProgress.xpPerLevel} XP',
                      style: AppText.caption(color: AppColors.textCream),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(left: 7, top: 7, child: PixelNail()),
            const Positioned(right: 7, top: 7, child: PixelNail()),
          ],
        ),
      ],
    );
  }
}

/// A little wooden marker on a stick, stuck in the soil.
class _GardenStake extends StatelessWidget {
  const _GardenStake({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelPanel(
          style: PanelStyle.wood,
          expand: false,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(label, style: AppTheme.body(size: 10, color: AppColors.textCream, weight: FontWeight.w900)),
        ),
        Container(width: 4, height: 30, color: const Color(0xFF6B4226)),
      ],
    );
  }
}

class _HarvestedPlant extends StatelessWidget {
  const _HarvestedPlant({required this.number, required this.species, required this.size});

  final int number;
  final PlantSpecies species;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${species.name} number $number',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => showPixelMessage(
          context,
          title: species.name,
          buttonLabel: 'Back to garden',
          sealIcon: Icons.local_florist,
          body: Column(
            children: [
              PixelSprite(species.fullGrownAsset, size: 128),
              const SizedBox(height: AppSpacing.sm),
              Text('Plant #$number', style: AppText.panelTitle(color: AppColors.textDark)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${species.category} · ${species.rarity.label}',
                style: AppText.small(color: AppColors.greenDeep, weight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Grown with ${GrowthStage.values.length - 1} focus sessions.',
                textAlign: TextAlign.center,
                style: AppText.body(),
              ),
            ],
          ),
        ),
        child: PixelSprite(species.fullGrownAsset, size: size),
      ),
    );
  }
}

/// Dark soil strip with a lit top edge and a few pebbles.
class _SoilPainter extends CustomPainter {
  static const double px = AppSizes.artScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF5A3A22));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, px), Paint()..color = const Color(0xFF2B1D12));
    canvas.drawRect(Rect.fromLTWH(0, px, size.width, px), Paint()..color = const Color(0xFF7A5234));
    final pebble = Paint()..color = const Color(0xFF8A6A4E);
    for (var x = 14.0; x < size.width; x += 37) {
      canvas.drawRect(Rect.fromLTWH(x, size.height * 0.45 + (x % 3) * 2, px * 2, px), pebble);
    }
  }

  @override
  bool shouldRepaint(_SoilPainter old) => false;
}

/// Cream picket fence: two rails behind, pickets with stepped points.
class _FencePainter extends CustomPainter {
  const _FencePainter();

  static const double px = AppSizes.artScale;
  static const double picketWidth = 10;
  static const double gap = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()..color = AppColors.panelDark;
    final wood = Paint()..color = const Color(0xFFEAD7B0);
    final shade = Paint()..color = const Color(0xFFC4A77A);

    // Rails (behind the pickets, visible in the gaps).
    for (final y in [size.height * 0.35, size.height * 0.72]) {
      canvas.drawRect(Rect.fromLTWH(0, y - px, size.width, 6 + px * 2), outline);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 6), shade);
    }

    for (var x = 4.0; x < size.width; x += picketWidth + gap) {
      // Outline first (1 art pixel bigger all round), then the wood.
      canvas.drawRect(Rect.fromLTWH(x - px, 6 - px, picketWidth + px * 2, size.height), outline);
      canvas.drawRect(Rect.fromLTWH(x + px - px, 2 - px, picketWidth - px * 2 + px * 2, 4 + px), outline);
      canvas.drawRect(Rect.fromLTWH(x + 4 - px, 0 - px, 2 + px * 2, 2 + px), outline);
      // Body + stepped point.
      canvas.drawRect(Rect.fromLTWH(x, 6, picketWidth, size.height - 6), wood);
      canvas.drawRect(Rect.fromLTWH(x + px, 2, picketWidth - px * 2, 4), wood);
      canvas.drawRect(Rect.fromLTWH(x + 4, 0, 2, 2), wood);
      // Shaded right edge.
      canvas.drawRect(Rect.fromLTWH(x + picketWidth - px, 6, px, size.height - 6), shade);
    }
  }

  @override
  bool shouldRepaint(_FencePainter old) => false;
}

// ---------------------------------------------------------------------------
// Stats plank, quest card, collection shelf
// ---------------------------------------------------------------------------

/// One dark plank with three stats split by dividers.
class _StatsLedger extends StatelessWidget {
  const _StatsLedger({required this.streak, required this.sessions, required this.grown});

  final int streak;
  final int sessions;
  final int grown;

  @override
  Widget build(BuildContext context) {
    Widget divider() => Container(width: AppSizes.artScale, height: 36, color: const Color(0xFF5B3E28));

    return PixelPanel(
      style: PanelStyle.dark,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          // "in a row" instead of "days": the streak counts sessions in a
          // row, not calendar days (yet).
          _ledgerItem(Icons.local_fire_department, '$streak', 'in a row'),
          divider(),
          _ledgerItem(Icons.timer, '$sessions', 'sessions'),
          divider(),
          _ledgerItem(Icons.local_florist, '$grown', 'grown'),
        ],
      ),
    );
  }

  Widget _ledgerItem(IconData icon, String value, String label) {
    return Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: AppColors.accentGold),
                const SizedBox(width: 6),
                Text(value, style: AppTheme.pixelHeading(size: 13, color: AppColors.textCream)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppText.caption(color: AppColors.textCream.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }
}

/// "NEXT UNLOCK: Desert Cactus" with a progress bar toward it.
class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.completedSessions});

  final int completedSessions;

  @override
  Widget build(BuildContext context) {
    final next = nextUnlock(completedSessions);

    return PixelPanel(
      style: PanelStyle.parchment,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 64,
            child: PixelPanel(
              style: PanelStyle.dark,
              sunken: true,
              shadow: false,
              padding: EdgeInsets.zero,
              child: Center(
                child: next == null
                    ? const Icon(Icons.star, color: AppColors.accentGold, size: 26)
                    : Text('?', style: AppTheme.pixelHeading(size: 22, color: AppColors.accentGold)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: next == null
                ? Text('Every plant unlocked. What a garden!', style: AppText.body())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT UNLOCK',
                        style: AppText.caption(color: AppColors.panelMedium).copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(next.name, style: AppTheme.body(size: 16, weight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.sm),
                      PixelProgressBar(
                        value: completedSessions / next.unlockAtSessions,
                        height: 12,
                        semanticLabel: 'Progress to ${next.name}',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Focus ${next.unlockAtSessions - completedSessions} more sessions  ·  '
                        '$completedSessions / ${next.unlockAtSessions}',
                        style: AppText.caption(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Collectible plant cards standing on a wooden shelf. Swipe sideways.
class _CollectionShelf extends StatelessWidget {
  const _CollectionShelf({required this.completedSessions, required this.harvestLog});

  final int completedSessions;
  final List<String> harvestLog;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 16,
            child: PixelPanel(style: PanelStyle.wood, padding: EdgeInsets.zero, child: SizedBox.expand()),
          ),
          Positioned.fill(
            bottom: 12,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              itemCount: plantCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) {
                final species = plantCatalog[i];
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: _CollectibleCard(
                    species: species,
                    unlocked: isUnlocked(species, completedSessions),
                    count: harvestLog.where((id) => id == species.id).length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectibleCard extends StatelessWidget {
  const _CollectibleCard({required this.species, required this.unlocked, required this.count});

  final PlantSpecies species;
  final bool unlocked;
  final int count;

  static const double _width = 116;
  static const double _height = 172;

  static Color _rarityColor(PlantRarity rarity) => switch (rarity) {
        PlantRarity.common => const Color(0xFF5E8A34),
        PlantRarity.uncommon => const Color(0xFF3F74A6),
        PlantRarity.rare => const Color(0xFF8A57B0),
        PlantRarity.legendary => const Color(0xFFC08A1E),
      };

  @override
  Widget build(BuildContext context) {
    final String footer;
    if (!unlocked) {
      footer = '${species.unlockAtSessions} sessions';
    } else {
      footer = count == 0 ? 'Ready to plant' : 'Grown ×$count';
    }

    final band = Container(
      height: 20,
      alignment: Alignment.center,
      color: unlocked ? _rarityColor(species.rarity) : const Color(0xFF5B3E28),
      child: Text(
        species.rarity.label.toUpperCase(),
        style: AppTheme.body(size: 11, color: AppColors.textCream, weight: FontWeight.w900).copyWith(letterSpacing: 0.5),
      ),
    );

    final Widget art;
    if (!unlocked) {
      art = Text('?', style: AppTheme.pixelHeading(size: 26, color: AppColors.accentGold.withValues(alpha: 0.7)));
    } else {
      art = PixelSprite(species.fullGrownAsset, size: 80, zoom: 1.4);
    }

    return Semantics(
      label: unlocked ? '${species.name}, ${species.rarity.label}, $footer' : 'Locked plant, unlocks at $footer',
      excludeSemantics: true,
      child: SizedBox(
        width: _width,
        height: _height,
        child: PixelPanel(
          style: unlocked ? PanelStyle.parchment : PanelStyle.dark,
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              band,
              const SizedBox(height: 6),
              Expanded(
                child: PixelPanel(
                  style: unlocked ? PanelStyle.parchment : PanelStyle.dark,
                  sunken: true,
                  shadow: false,
                  padding: EdgeInsets.zero,
                  child: Center(child: art),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                unlocked ? species.name.toUpperCase() : '???',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  size: 11,
                  color: unlocked ? AppColors.textDark : AppColors.textCream,
                  weight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                footer,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(color: unlocked ? AppColors.panelMedium : AppColors.accentGold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
