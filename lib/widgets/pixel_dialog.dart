import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_scroll.dart';

export 'pixel_scroll.dart' show WaxSeal;

/// A popup written on a rolled paper scroll: optional wax seal on top, a
/// pixel title with little leaf flourishes, a dotted divider, the
/// content, then the buttons stacked underneath (stacked, not side by
/// side, so long labels never get squeezed). Scrolls on tiny phones.
class PixelDialog extends StatelessWidget {
  const PixelDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
    this.sealIcon,
    this.sealColor = WaxSeal.green,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Icon stamped in the wax seal. null = no seal.
  final IconData? sealIcon;
  final Color sealColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: PixelScroll(
          seal: sealIcon == null ? null : WaxSeal(icon: sealIcon!, color: sealColor),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScrollTitle(title),
                const SizedBox(height: AppSpacing.md),
                body,
                const SizedBox(height: 20),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  actions[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "🌿 Title 🌿" and a dotted divider with a small diamond in the middle.
class _ScrollTitle extends StatelessWidget {
  const _ScrollTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          header: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.eco, size: 14, color: AppColors.greenDeep),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(title, textAlign: TextAlign.center, style: AppText.screenTitle()),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Mirrored leaf on the right.
              Transform.flip(flipX: true, child: const Icon(Icons.eco, size: 14, color: AppColors.greenDeep)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const SizedBox(height: 6, width: double.infinity, child: CustomPaint(painter: _DividerPainter())),
      ],
    );
  }
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter();

  static const double px = AppSizes.artScale;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0xFFC4A274);
    final mid = size.width / 2;
    final y = size.height / 2 - px / 2;
    for (var x = 8.0; x < size.width - 8; x += 8) {
      if ((x - mid).abs() < 12) continue;
      canvas.drawRect(Rect.fromLTWH(x, y, px * 2, px), dot);
    }
    // Little diamond in the middle.
    final gem = Paint()..color = AppColors.panelMedium;
    canvas.drawRect(Rect.fromLTWH(mid - px, 0, px * 2, size.height), gem);
    canvas.drawRect(Rect.fromLTWH(mid - px * 2, px, px * 4, size.height - px * 2), gem);
  }

  @override
  bool shouldRepaint(_DividerPainter old) => false;
}

/// Yes/No question. Returns true only if the confirm button was tapped.
/// The cancel button comes FIRST so the safe choice is the easy one.
Future<bool> showPixelConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool danger = false,
  IconData? sealIcon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.overlay,
    builder: (dialogContext) => PixelDialog(
      title: title,
      sealIcon: sealIcon,
      sealColor: danger ? WaxSeal.red : WaxSeal.green,
      body: Text(message, textAlign: TextAlign.center, style: AppText.body()),
      actions: [
        PixelButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PixelButton(
          label: confirmLabel,
          tone: danger ? ButtonTone.danger : ButtonTone.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return result == true;
}

/// A popup with some content and a single close button.
Future<void> showPixelMessage(
  BuildContext context, {
  required String title,
  required Widget body,
  String buttonLabel = 'Got it',
  IconData? sealIcon,
  Color sealColor = WaxSeal.green,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.overlay,
    builder: (dialogContext) => PixelDialog(
      title: title,
      sealIcon: sealIcon,
      sealColor: sealColor,
      body: body,
      actions: [
        PixelButton(label: buttonLabel, onPressed: () => Navigator.of(dialogContext).pop()),
      ],
    ),
  );
}
