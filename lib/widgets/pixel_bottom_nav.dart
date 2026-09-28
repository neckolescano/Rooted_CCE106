import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

class PixelNavItem {
  const PixelNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The Home · Garden · Profile bar. Looks like a game menu: a dark wooden
/// plank, and the selected tab sits in a wood slot with a gold outline.
///
/// Every slot is always the same size whether selected or not — the old
/// bar had a 3px overflow because only the selected tab had a border.
class PixelBottomNav extends StatelessWidget {
  const PixelBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<PixelNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Room for phones with a gesture bar at the bottom.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return CustomPaint(
      painter: _PlankPainter(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.sm, 10, AppSpacing.sm, AppSpacing.sm + bottomInset),
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _slot(items[i], i == currentIndex, () => onTap(i))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(PixelNavItem item, bool selected, VoidCallback onTap) {
    final dimCream = AppColors.textCream.withValues(alpha: 0.75);
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 22, color: selected ? AppColors.accentGold : dimCream),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.label,
            style: AppTheme.body(
              size: 11,
              color: selected ? AppColors.textCream : dimCream,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: SizedBox.expand(
            child: selected
                ? PixelPanel(
                    style: PanelStyle.wood,
                    outlineColor: AppColors.accentGold,
                    shadow: false,
                    padding: EdgeInsets.zero,
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    );
  }
}

/// Dark plank with a black line + lit line along the top edge.
class _PlankPainter extends CustomPainter {
  static const double px = AppSizes.artScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.panelDark);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, px), Paint()..color = const Color(0xFF1E140C));
    canvas.drawRect(Rect.fromLTWH(0, px, size.width, px), Paint()..color = const Color(0xFF5B3E28));
  }

  @override
  bool shouldRepaint(_PlankPainter old) => false;
}
