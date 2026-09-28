import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_designs.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'card_cover.dart';
import 'pixel_button.dart';
import 'pixel_dialog.dart';
import 'pixel_panel.dart';
import 'pixel_progress_bar.dart';

/// The "Card designs" shelf on the Profile: every Player Card design as a
/// small cover you can scroll sideways (like the seed collection).
/// Unlocked ones can be equipped; locked ones show their quest progress.
/// Tap any card to see it big.
class CardDesignShelf extends StatelessWidget {
  const CardDesignShelf({super.key, required this.stats});

  final QuestStats stats;

  static const double _cardWidth = 128;
  static const double _coverHeight = 80;

  @override
  Widget build(BuildContext context) {
    final equipped = context.watch<StorageService>().cardDesign;

    return SizedBox(
      // Cover + name + progress line, with room for the drop shadow.
      height: _coverHeight + 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cardDesigns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final design = cardDesigns[i];
          return _ShelfCard(
            design: design,
            unlocked: design.isUnlocked(stats),
            equipped: design.id == equipped,
            progressLabel: design.progressLabel(stats),
            onTap: () => showCardDesignPreview(context, design: design, stats: stats),
          );
        },
      ),
    );
  }
}

/// One card on the shelf: small cover (darkened + lock when locked),
/// name, and either EQUIPPED / "tap to equip" or the quest progress.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.design,
    required this.unlocked,
    required this.equipped,
    required this.progressLabel,
    required this.onTap,
  });

  final CardDesign design;
  final bool unlocked;
  final bool equipped;
  final String progressLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = equipped ? 'Equipped' : (unlocked ? 'Unlocked' : 'Locked, $progressLabel');

    return Semantics(
      button: true,
      selected: equipped,
      label: '${design.name} card design, $status',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: CardDesignShelf._cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: CardDesignShelf._coverHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CardCover(design: design, small: true),
                    if (!unlocked)
                      // Dim the picture so it reads as "not yours yet",
                      // but keep it visible so there's something to want.
                      const _LockVeil(),
                    if (equipped)
                      const Positioned(
                        right: 4,
                        top: 4,
                        child: _CornerTag(icon: Icons.check, color: AppColors.greenDeep),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                design.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small(color: unlocked ? AppColors.textDark : AppColors.textMuted, weight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              if (equipped)
                Text('EQUIPPED', style: AppText.caption(color: AppColors.greenDeep))
              else if (unlocked)
                Text('Tap to equip', style: AppText.caption(color: AppColors.panelMedium))
              else
                Row(
                  children: [
                    const Icon(Icons.lock, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(progressLabel, style: AppText.caption()),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark wash + lock over a locked cover.
class _LockVeil extends StatelessWidget {
  const _LockVeil();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x993E2A1B), // panelDark at 60%
      alignment: Alignment.center,
      child: const Icon(Icons.lock, size: 22, color: AppColors.accentGold),
    );
  }
}

/// Tiny dark tag with an icon, pinned to a cover corner.
class _CornerTag extends StatelessWidget {
  const _CornerTag({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PixelPanel(
      style: PanelStyle.parchment,
      expand: false,
      shadow: false,
      padding: const EdgeInsets.all(2),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

/// Opens the big preview scroll for one design: the full-size cover, its
/// quest with a progress bar, and an Equip button if it's unlocked.
Future<void> showCardDesignPreview(
  BuildContext context, {
  required CardDesign design,
  required QuestStats stats,
}) {
  final storage = context.read<StorageService>();
  final unlocked = design.isUnlocked(stats);
  final equipped = storage.cardDesign == design.id;

  return showDialog<void>(
    context: context,
    barrierColor: AppColors.overlay,
    builder: (dialogContext) => PixelDialog(
      title: design.name,
      sealIcon: unlocked ? Icons.style : Icons.lock,
      sealColor: design.golden ? WaxSeal.gold : (unlocked ? WaxSeal.green : WaxSeal.red),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CardCover(design: design),
                if (!unlocked) const _LockVeil(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            unlocked ? 'QUEST COMPLETE' : 'QUEST',
            textAlign: TextAlign.center,
            style: AppText.small(color: unlocked ? AppColors.greenDeep : AppColors.textMuted, weight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(design.quest, textAlign: TextAlign.center, style: AppText.body()),
          if (!unlocked) ...[
            const SizedBox(height: AppSpacing.sm),
            PixelProgressBar(
              value: design.progress(stats),
              height: 12,
              fillColor: AppColors.accentGold,
              semanticLabel: 'Quest progress ${design.progressLabel(stats)}',
            ),
            const SizedBox(height: 4),
            Text(design.progressLabel(stats), textAlign: TextAlign.center, style: AppText.small(color: AppColors.textMuted)),
          ],
        ],
      ),
      actions: [
        if (unlocked && !equipped)
          PixelButton(
            label: 'Equip',
            onPressed: () {
              storage.setCardDesign(design.id);
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
