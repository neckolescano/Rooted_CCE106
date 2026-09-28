import 'dart:math';
import 'package:flutter/material.dart';
import '../models/study_material.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// One flashcard, tap to flip between front and back. `flipped` and
/// `onTap` are controlled by the parent screen so it can track which
/// card is showing which side.
///
/// Front = parchment (the question), back = wood (the answer), like a
/// collectible card. When you draw card_front.png / card_back.png, they
/// replace the two PixelPanels in _face().
class FlashcardWidget extends StatelessWidget {
  const FlashcardWidget({
    super.key,
    required this.flashcard,
    required this.flipped,
    required this.onTap,
  });

  final Flashcard flashcard;
  final bool flipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: flipped ? 'Answer: ${flashcard.back}. Tap to see the term.' : 'Term: ${flashcard.front}. Tap to see the answer.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // Spins the card around its vertical axis. Past halfway the back
        // face is shown (mirrored back so its text reads normally).
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: flipped ? pi : 0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          builder: (context, angle, _) {
            final showingBack = angle > pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // a little perspective
                ..rotateY(angle),
              child: showingBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _face(isBack: true),
                    )
                  : _face(isBack: false),
            );
          },
        ),
      ),
    );
  }

  Widget _face({required bool isBack}) {
    final textColor = isBack ? AppColors.textCream : AppColors.textDark;
    final accent = isBack ? AppColors.accentGold : AppColors.greenDeep;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 240, maxWidth: 420),
      child: PixelPanel(
        style: isBack ? PanelStyle.wood : PanelStyle.parchment,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isBack ? Icons.lightbulb : Icons.spa, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(isBack ? 'ANSWER' : 'TERM', style: AppText.gameMoment(color: accent)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isBack ? flashcard.back : flashcard.front,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 17, color: textColor, weight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Text(
              'Tap to flip',
              style: AppText.caption(color: textColor.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}
