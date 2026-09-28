import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// A small square wooden button with an icon (and optionally a short
/// label), e.g. Back, Pause, the NOTES chip. Always at least 48x48 so it's
/// easy to tap, and always has a [semanticLabel] for screen readers.
class PixelIconButton extends StatefulWidget {
  const PixelIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.label,
    this.style = PanelStyle.dark,
    this.iconColor = AppColors.accentGold,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Optional text shown next to the icon, e.g. "NOTES".
  final String? label;
  final PanelStyle style;
  final Color iconColor;

  @override
  State<PixelIconButton> createState() => _PixelIconButtonState();
}

class _PixelIconButtonState extends State<PixelIconButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = widget.style == PanelStyle.parchment ? AppColors.textDark : widget.iconColor;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Transform.translate(
            offset: Offset(0, _pressed ? AppSizes.artScale : 0),
            child: PixelPanel(
              style: widget.style,
              expand: false,
              shadow: !_pressed,
              padding: EdgeInsets.symmetric(horizontal: widget.label == null ? 0 : AppSpacing.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppSizes.minTouchTarget,
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 20, color: color),
                    if (widget.label != null) ...[
                      const SizedBox(width: 6),
                      Text(widget.label!, style: AppText.panelTitle(color: color)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
