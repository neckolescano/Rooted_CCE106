import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// A small stat box: icon + number on top, a short label below.
/// e.g. 🔥 3 / "in a row". Put 3–4 in a Row with Expanded.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.style = PanelStyle.dark,
  });

  final IconData icon;
  final String value;
  final String label;
  final PanelStyle style;

  @override
  Widget build(BuildContext context) {
    final onLight = style == PanelStyle.parchment;
    final textColor = onLight ? AppColors.textDark : AppColors.textCream;
    final iconColor = onLight ? AppColors.panelMedium : AppColors.accentGold;

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: PixelPanel(
        style: style,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.body(size: 15, color: textColor, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(color: textColor.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
