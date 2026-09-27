import 'package:flutter/material.dart';
import '../models/study_material.dart';
import '../theme/app_theme.dart';

/// One flashcard, tap to flip between front and back. `flipped` and
/// `onTap` are controlled by the parent screen so it can track which
/// card is showing which side.
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: flipped ? AppColors.panelLight : AppColors.panelMedium,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.panelDark, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              flipped ? 'ANSWER' : 'TERM',
              style: AppTheme.body(size: 10, color: AppColors.accentGold, weight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              flipped ? flashcard.back : flashcard.front,
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 15, color: AppColors.textCream, weight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to flip',
              style: AppTheme.body(size: 10, color: AppColors.textCream.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
