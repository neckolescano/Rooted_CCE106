import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_designs.dart' show QuestStats;
import '../models/garden_scenes.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'garden_scene_backdrop.dart';
import 'pixel_button.dart';
import 'pixel_dialog.dart';
import 'pixel_panel.dart';
import 'pixel_progress_bar.dart';

/// The "Garden scenes" shelf on the Garden page: every scene as a small
/// picture you can scroll sideways (like the seed collection). Unlocked
/// ones can be equipped — that changes the Timer background, the Garden
/// Archive and the view through the Home window. Locked ones show their
/// quest progress. Tap any scene to preview it (moving).
class GardenSceneShelf extends StatelessWidget {
  const GardenSceneShelf({super.key, required this.stats});

  final QuestStats stats;

  static const double _cardWidth = 128;
  static const double _pictureHeight = 80;

  @override
  Widget build(BuildContext context) {
    final equipped = context.watch<StorageService>().gardenScene;

    return SizedBox(
      height: _pictureHeight + 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gardenScenes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final scene = gardenScenes[i];
          final unlocked = scene.isUnlocked(stats);
          final isEquipped = scene.id == equipped;
          final hidden = scene.secret && !unlocked;
          final status = isEquipped
              ? 'Equipped'
              : (unlocked ? 'Unlocked' : (hidden ? 'Secret, locked' : 'Locked, ${scene.progressLabel(stats)}'));
          return Semantics(
            button: true,
            selected: isEquipped,
            label: '${hidden ? 'Secret' : scene.name} scene, $status',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showGardenScenePreview(context, scene: scene, stats: stats),
              child: SizedBox(
                width: _cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _pictureHeight,
                      child: _Framed(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Still pictures on the shelf (the preview moves).
                            if (hidden) const _SecretVeil() else GardenSceneBackdrop(
                              scene: scene,
                              alignment: const Alignment(0.3, 0.2),
                              pixel: 1,
                              animate: false,
                              filterQuality: FilterQuality.medium,
                            ),
                            if (!unlocked && !hidden) const _LockVeil(),
                            if (isEquipped)
                              const Positioned(right: 4, top: 4, child: _CheckTag()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hidden ? '❔ ???' : '${scene.emoji} ${scene.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.small(color: unlocked ? AppColors.textDark : AppColors.textMuted, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    if (isEquipped)
                      Text('EQUIPPED', style: AppText.caption(color: AppColors.greenDeep))
                    else if (unlocked)
                      Text('Tap to equip', style: AppText.caption(color: AppColors.panelMedium))
                    else
                      Row(
                        children: [
                          const Icon(Icons.lock, size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(hidden ? 'Secret' : scene.progressLabel(stats), style: AppText.caption()),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A thin wooden picture frame.
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: PanelStyle.wood,
      padding: const EdgeInsets.all(4),
      shadow: false,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(border: Border.all(color: AppColors.panelDark, width: AppBorders.width)),
        child: ClipRect(child: child),
      ),
    );
  }
}

/// A secret scene before it is found: just a starry dark card with a "?".
class _SecretVeil extends StatelessWidget {
  const _SecretVeil();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF120C24), Color(0xFF2A2250), Color(0xFF1C3A3A)],
        ),
      ),
      alignment: Alignment.center,
      child: Text('?', style: AppTheme.pixelHeading(size: 26, color: AppColors.accentGold)),
    );
  }
}

/// Dark wash + lock over a locked scene.
class _LockVeil extends StatelessWidget {
  const _LockVeil();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x993E2A1B),
      alignment: Alignment.center,
      child: const Icon(Icons.lock, size: 22, color: AppColors.accentGold),
    );
  }
}

class _CheckTag extends StatelessWidget {
  const _CheckTag();

  @override
  Widget build(BuildContext context) {
    return const PixelPanel(
      style: PanelStyle.parchment,
      expand: false,
      shadow: false,
      padding: EdgeInsets.all(2),
      child: Icon(Icons.check, size: 12, color: AppColors.greenDeep),
    );
  }
}

/// The big preview scroll for one scene: the scene moving, what it
/// changes, its quest with a progress bar, and Equip if it's unlocked.
Future<void> showGardenScenePreview(
  BuildContext context, {
  required GardenScene scene,
  required QuestStats stats,
}) {
  final storage = context.read<StorageService>();
  final unlocked = scene.isUnlocked(stats);
  final equipped = storage.gardenScene == scene.id;
  final hidden = scene.secret && !unlocked;

  return showDialog<void>(
    context: context,
    barrierColor: AppColors.overlay,
    builder: (dialogContext) => PixelDialog(
      title: hidden ? '???' : scene.name,
      sealIcon: unlocked ? Icons.landscape : (hidden ? Icons.help_outline : Icons.lock),
      sealColor: unlocked ? WaxSeal.green : WaxSeal.red,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: _Framed(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hidden)
                    const _SecretVeil()
                  else
                    GardenSceneBackdrop(scene: scene, alignment: const Alignment(0.3, 0.2), pixel: 1.5),
                  if (!unlocked && !hidden) const _LockVeil(),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Changes your Timer, your Garden Archive and the view from the greenhouse window.',
            textAlign: TextAlign.center,
            style: AppText.small(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            unlocked ? (scene.secret ? 'SECRET FOUND' : 'QUEST COMPLETE') : (hidden ? 'A SECRET SCENE' : 'QUEST'),
            textAlign: TextAlign.center,
            style: AppText.small(color: unlocked ? AppColors.greenDeep : AppColors.textMuted, weight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(hidden ? (scene.hint ?? '') : scene.quest, textAlign: TextAlign.center, style: AppText.body()),
          if (!unlocked && !hidden) ...[
            const SizedBox(height: AppSpacing.sm),
            PixelProgressBar(
              value: scene.progress(stats),
              height: 12,
              fillColor: AppColors.accentGold,
              semanticLabel: 'Quest progress ${scene.progressLabel(stats)}',
            ),
            const SizedBox(height: 4),
            Text(scene.progressLabel(stats), textAlign: TextAlign.center, style: AppText.small(color: AppColors.textMuted)),
          ],
        ],
      ),
      actions: [
        if (unlocked && !equipped)
          PixelButton(
            label: 'Equip',
            onPressed: () {
              storage.setGardenScene(scene.id);
              Navigator.of(dialogContext).pop();
            },
          ),
        PixelButton(
          label: equipped ? 'Equipped ✓' : 'Close',
          tone: ButtonTone.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}
