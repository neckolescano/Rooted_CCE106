import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_dialog.dart';
import 'pixel_icon_button.dart';
import 'pixel_panel.dart';

/// "⏱ FOCUS TIME  [–] 25 min [+]" — picks how long the next study session
/// lasts. The choice is saved (StorageService.focusMinutes) and the Timer
/// screen counts down exactly that long.
class FocusTimeSetter extends StatelessWidget {
  const FocusTimeSetter({super.key});

  /// The lengths the – / + buttons step through (minutes). Short ones for
  /// quick tests, then Pomodoro-friendly steps of 5, then long sessions.
  static const steps = [1, 2, 3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 120];

  /// Quick picks in the presets scroll.
  static const presets = [5, 10, 15, 25, 30, 45, 60, 90];

  static const classic = 25;

  static String label(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m';
  }

  /// Index of the step closest to [minutes] (saved values may be anything).
  static int _nearestStep(int minutes) {
    var best = 0;
    for (var i = 0; i < steps.length; i++) {
      if ((steps[i] - minutes).abs() < (steps[best] - minutes).abs()) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final minutes = storage.focusMinutes;
    final index = _nearestStep(minutes);

    void setTo(int value) => storage.setFocusMinutes(value);

    return PixelPanel(
      style: PanelStyle.dark,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, 4, 4),
      child: Row(
        children: [
          const Icon(Icons.timer, size: 18, color: AppColors.accentGold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('FOCUS TIME', style: AppText.panelTitle()),
          ),
          PixelIconButton(
            icon: Icons.remove,
            semanticLabel: 'Shorter session',
            style: PanelStyle.wood,
            iconColor: AppColors.textCream,
            onPressed: index == 0 ? null : () => setTo(steps[index - 1]),
          ),
          // Tap the number for quick presets.
          Semantics(
            button: true,
            label: 'Focus time ${label(minutes)}. Tap for presets.',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final picked = await _showPresets(context, minutes);
                if (picked != null) setTo(picked);
              },
              child: SizedBox(
                width: 84,
                height: AppSizes.minTouchTarget,
                child: Center(
                  child: Text(
                    label(minutes),
                    style: AppTheme.pixelHeading(size: 11, color: AppColors.accentGold)
                        .copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.accentGold),
                  ),
                ),
              ),
            ),
          ),
          PixelIconButton(
            icon: Icons.add,
            semanticLabel: 'Longer session',
            style: PanelStyle.wood,
            iconColor: AppColors.textCream,
            onPressed: index == steps.length - 1 ? null : () => setTo(steps[index + 1]),
          ),
        ],
      ),
    );
  }

  Future<int?> _showPresets(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (dialogContext) => PixelDialog(
        title: 'Focus time',
        sealIcon: Icons.timer,
        body: Column(
          children: [
            Text(
              'How long will you nurture your plant?',
              textAlign: TextAlign.center,
              style: AppText.body(),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in presets)
                  _PresetChip(
                    minutes: m,
                    selected: m == current,
                    onTap: () => Navigator.of(dialogContext).pop(m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '★ 25 min is the classic Pomodoro',
              textAlign: TextAlign.center,
              style: AppText.caption(color: AppColors.greenDeep).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          PixelButton(
            label: 'Close',
            tone: ButtonTone.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.minutes, required this.selected, required this.onTap});

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isClassic = minutes == FocusTimeSetter.classic;
    return Semantics(
      button: true,
      selected: selected,
      label: FocusTimeSetter.label(minutes),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: PixelPanel(
          style: selected ? PanelStyle.wood : PanelStyle.parchment,
          outlineColor: selected ? AppColors.accentGold : null,
          sunken: !selected,
          shadow: false,
          expand: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: SizedBox(
            width: 64,
            child: Text(
              '${isClassic ? '★ ' : ''}${FocusTimeSetter.label(minutes)}',
              textAlign: TextAlign.center,
              style: AppTheme.body(
                size: 13,
                color: selected ? AppColors.textCream : AppColors.textDark,
                weight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
