import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The bordered brown box used everywhere in the Figma — the header bar,
/// the plant scene frame, the garden row, etc. One widget, reused with
/// different colors/padding instead of rebuilding this styling each time.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.backgroundColor = AppColors.panelMedium,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.panelDark, width: 2),
      ),
      child: child,
    );
  }
}
