import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// The big countdown: a wooden sign with nails in the corners and the
/// time set into a dark slot, like a greenhouse clock. The digits are the
/// biggest thing on the Timer screen on purpose.
///
/// When you draw timer_sign.png later, swap the outer PixelPanel for it.
class PixelTimerDisplay extends StatelessWidget {
  const PixelTimerDisplay({super.key, required this.time, required this.label});

  /// e.g. "18:42"
  final String time;

  /// e.g. "FOCUS MODE", "PAUSED"
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $time left',
      excludeSemantics: true,
      child: Stack(
        children: [
          PixelPanel(
            style: PanelStyle.wood,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                PixelPanel(
                  style: PanelStyle.dark,
                  expand: false,
                  shadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
                  child: Text(label, style: AppText.caption(color: AppColors.accentGold)),
                ),
                const SizedBox(height: 10),
                PixelPanel(
                  style: PanelStyle.dark,
                  sunken: true,
                  shadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(time, style: AppText.timerLarge()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Four little nails, like the ones on the harvest scroll art.
          const Positioned(left: 7, top: 7, child: PixelNail()),
          const Positioned(right: 7, top: 7, child: PixelNail()),
          const Positioned(left: 7, bottom: 7, child: PixelNail()),
          const Positioned(right: 7, bottom: 7, child: PixelNail()),
        ],
      ),
    );
  }
}
