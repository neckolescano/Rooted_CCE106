import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/garden_progress.dart';
import '../models/plant_catalog.dart';
import '../models/plant_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/focus_time_setter.dart';
import '../widgets/greenhouse_scene.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/pixel_progress_bar.dart';
import '../widgets/page_entrance.dart';
import '../widgets/seed_picker.dart';
import '../widgets/window_zoom.dart';
import 'timer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Marks the greenhouse window, so the zoom knows where to fly into.
  static final _windowKey = GlobalKey(debugLabel: 'greenhouseWindow');

  void _startSession(BuildContext context) {
    final zoom = WindowZoom.maybeOf(context);
    final route = WindowZoom.throughWindowRoute<void>(const TimerScreen());
    if (zoom == null) {
      Navigator.of(context).push(route);
    } else {
      // The window swings open, the plant ducks, and the camera flies out
      // through the middle into the meadow (the Timer screen).
      zoom.zoomThrough(_windowKey, route);
    }
  }

  /// A little rotating encouragement line under the plant, matching the
  /// "Your cozy Fern is craving some focus light!" line in the Figma.
  String _quoteFor(PlantModel plant) {
    if (plant.isWilted) return 'Your plant could use a comeback session.';
    switch (plant.stage) {
      case GrowthStage.seed:
        return 'A tiny seed, waiting for its first session.';
      case GrowthStage.sprout:
        return 'Your cozy sprout is craving some focus light!';
      case GrowthStage.grow:
        return 'It\'s really taking shape — keep it up.';
      case GrowthStage.bloom:
        return 'Almost fully grown — one more push!';
      case GrowthStage.fullGrown:
        return 'Fully grown! Start a new one whenever you\'re ready.';
    }
  }

  /// What kuwago says when tapped on Home — about YOUR garden right now,
  /// in this order (then it loops).
  List<String> _owlLines(PlantModel plant, StorageService storage, int completedSessions) {
    final name = plant.species.name;
    final choices = plantCatalog.where((s) => isUnlocked(s, completedSessions)).length;
    return [
      if (plant.isWilted)
        'Oh no, your $name wilted… one session will perk it up!'
      else
        switch (plant.stage) {
          GrowthStage.seed => "A fresh $name seed! Tap Start when you're ready.",
          GrowthStage.sprout => 'Look, your $name sprouted!',
          GrowthStage.grow => 'Your $name is getting leafy!',
          GrowthStage.bloom => 'One more session and your $name is fully grown!',
          GrowthStage.fullGrown => 'Wow, look at it bloom!',
        },
      'Focus time is ${FocusTimeSetter.label(storage.focusMinutes)}. You got this!',
      if (storage.streak >= 2) '${storage.streak} sessions in a row! Hoo-ray!' else 'Hoo! Ready to study?',
      if (plant.canChangeSpecies && choices > 1) 'Psst… tap the seed tag to plant something new.',
      'Tip: tap NOTES during a session to jot things down.',
      'Stay cozy, stay curious.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final plant = context.watch<PlantModel>();
    final storage = context.watch<StorageService>();
    final progress = GardenProgress.from(
      harvestedPlants: storage.harvestedPlants,
      plantStageIndex: plant.stage.index,
    );

    // Entrance: the header drops in, the greenhouse fades up (kuwago is
    // flown onto its sill by the opening), then the rest rises in turn.
    return PageEntrance(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EntranceItem(from: 0, to: 0.4, slide: -24, child: _Header(progress: progress, streak: storage.streak)),
            const SizedBox(height: AppSpacing.md),
            // The greenhouse takes all the leftover height, so on tall
            // phones the plant simply gets bigger — no empty cream gap.
            // (Fade only: it must not move while kuwago is landing in it.)
            Expanded(
              child: EntranceItem(
                from: 0.1,
                to: 0.5,
                slide: 0,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GreenhouseScene(
                        plant: plant,
                        windowKey: _windowKey,
                        owlMessages: _owlLines(plant, storage, progress.completedSessions),
                      ),
                    ),
                    // Seed packet tag: which plant is planted. Only a seed can
                    // be swapped, so it's tappable only before the first
                    // session of a new plant.
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _SeedTag(plant: plant, completedSessions: progress.completedSessions),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            EntranceItem(from: 0.35, to: 0.7, child: _GrowthTrack(plant: plant)),
            const SizedBox(height: AppSpacing.md),
            EntranceItem(
              from: 0.42,
              to: 0.77,
              child: Text(
                '"${_quoteFor(plant)}"',
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 13, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // How long the session will be — the Timer counts down this.
            const EntranceItem(from: 0.5, to: 0.85, child: FocusTimeSetter()),
            const SizedBox(height: AppSpacing.md),
            EntranceItem(
              from: 0.58,
              to: 0.95,
              child: PixelButton(
                label: 'Start Study Session',
                onPressed: () => _startSession(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Little dark tag in the greenhouse corner: "🌱 Desert Cactus · CHANGE".
class _SeedTag extends StatelessWidget {
  const _SeedTag({required this.plant, required this.completedSessions});

  final PlantModel plant;
  final int completedSessions;

  Future<void> _pick(BuildContext context) async {
    final storage = context.read<StorageService>();
    final id = await showSeedPicker(context, currentId: plant.speciesId, completedSessions: completedSessions);
    if (id == null || !plant.canChangeSpecies) return;
    plant.changeSpecies(id);
    await storage.savePlantSpecies(plant.speciesId);
  }

  @override
  Widget build(BuildContext context) {
    final canChange = plant.canChangeSpecies;
    // Only worth offering once there's more than one plant to choose.
    final choices = plantCatalog.where((s) => isUnlocked(s, completedSessions)).length;
    final tappable = canChange && choices > 1;

    final tag = PixelPanel(
      style: PanelStyle.dark,
      backgroundColor: const Color(0xE63E2A1B),
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.spa, size: 14, color: AppColors.accentGreen),
          const SizedBox(width: 6),
          Text(plant.species.name, style: AppText.caption(color: AppColors.textCream)),
          if (tappable) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              'CHANGE',
              style: AppText.caption(color: AppColors.accentGold).copyWith(
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accentGold),
            ),
          ],
        ],
      ),
    );

    if (!tappable) return Semantics(label: 'Growing ${plant.species.name}', child: tag);
    return Semantics(
      button: true,
      label: 'Planted seed: ${plant.species.name}. Change seed',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context),
        // Extra invisible padding so the small tag is still easy to tap.
        child: Padding(padding: const EdgeInsets.all(4), child: tag),
      ),
    );
  }
}

/// "COZY GREENHOUSE · GARDEN LV 2" with the XP bar and streak underneath.
class _Header extends StatelessWidget {
  const _Header({required this.progress, required this.streak});

  final GardenProgress progress;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final dimCream = AppColors.textCream.withValues(alpha: 0.8);

    return PixelPanel(
      style: PanelStyle.dark,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('COZY GREENHOUSE', style: AppText.panelTitle())),
              Text('GARDEN LV ${progress.level}', style: AppText.panelTitle(color: AppColors.accentGold)),
            ],
          ),
          const SizedBox(height: 10),
          PixelProgressBar(
            value: progress.levelProgress,
            height: 12,
            fillColor: AppColors.accentGold,
            semanticLabel: 'Garden experience',
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${progress.xpIntoLevel} / ${GardenProgress.xpPerLevel} XP',
                style: AppText.caption(color: dimCream),
              ),
              const Spacer(),
              const Icon(Icons.local_fire_department, size: 14, color: AppColors.accentGold),
              const SizedBox(width: AppSpacing.xs),
              Text('$streak in a row', style: AppText.caption(color: dimCream)),
            ],
          ),
        ],
      ),
    );
  }
}

/// "PLANT GROWTH · GROW 3/5" and the 5-chunk stage bar.
class _GrowthTrack extends StatelessWidget {
  const _GrowthTrack({required this.plant});

  final PlantModel plant;

  @override
  Widget build(BuildContext context) {
    final stageCount = GrowthStage.values.length;
    final stageNumber = plant.stage.index + 1;
    final status = plant.isWilted
        ? 'WILTED · $stageNumber/$stageCount'
        : '${plant.stage.label.toUpperCase()} · $stageNumber/$stageCount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('PLANT GROWTH', style: AppText.sectionLabel())),
            Text(
              status,
              style: AppText.small(
                color: plant.isWilted ? AppColors.dangerText : AppColors.greenDeep,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PixelProgressBar(
          value: stageNumber / stageCount,
          segments: stageCount,
          // A wilted plant's bar goes dry brown instead of green.
          fillColor: plant.isWilted ? const Color(0xFFA08560) : AppColors.accentGreen,
          semanticLabel: 'Plant growth stage $stageNumber of $stageCount',
        ),
      ],
    );
  }
}
