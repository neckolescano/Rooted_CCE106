import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Title above a group of things, e.g. "COZY SETTINGS", "YOUR GARDEN".
/// Same little gold marker + label on every screen.
class PixelSectionHeader extends StatelessWidget {
  const PixelSectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.color = AppColors.textDark,
  });

  final String title;

  /// Optional widget on the right, e.g. a count like "4 / 8".
  final Widget? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                border: Border.all(color: AppColors.panelDark, width: AppBorders.width),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title.toUpperCase(), style: AppText.sectionLabel(color: color))),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
