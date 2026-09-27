import 'package:flutter/material.dart';
import '../models/study_material.dart';
import '../theme/app_theme.dart';

/// One study question. Handles both shapes: multiple choice (tap a
/// choice to check it) and short answer (reveal the answer on tap).
class StudyQuestionCard extends StatefulWidget {
  const StudyQuestionCard({
    super.key,
    required this.question,
    required this.selectedChoice,
    required this.onSelectChoice,
  });

  final StudyQuestion question;
  final String? selectedChoice;
  final ValueChanged<String> onSelectChoice;

  @override
  State<StudyQuestionCard> createState() => _StudyQuestionCardState();
}

class _StudyQuestionCardState extends State<StudyQuestionCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.panelMedium.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.question, style: AppTheme.body(size: 14, weight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (q.isMultipleChoice) ..._buildChoices(q) else ..._buildShortAnswer(q),
          if (_revealed && (q.explanation?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              q.explanation!,
              style: AppTheme.body(size: 11, color: AppColors.textDark.withOpacity(0.65)),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildChoices(StudyQuestion q) {
    return q.choices!.map((choice) {
      final isSelected = widget.selectedChoice == choice;
      final isCorrectChoice = choice == q.answer;

      Color background = AppColors.background;
      Color border = AppColors.panelMedium.withOpacity(0.3);
      if (_revealed && isSelected) {
        background = isCorrectChoice ? AppColors.accentGreen.withOpacity(0.25) : const Color(0xFFE8A6A0);
        border = isCorrectChoice ? AppColors.accentGreen : const Color(0xFFCC6B5C);
      } else if (isSelected) {
        border = AppColors.panelMedium;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () {
            widget.onSelectChoice(choice);
            setState(() => _revealed = true);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Text(choice, style: AppTheme.body(size: 12)),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildShortAnswer(StudyQuestion q) {
    if (!_revealed) {
      return [
        GestureDetector(
          onTap: () => setState(() => _revealed = true),
          child: Text(
            'Reveal answer',
            style: AppTheme.body(size: 12, color: AppColors.panelMedium, weight: FontWeight.bold)
                .copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ];
    }
    return [
      Text(
        q.answer,
        style: AppTheme.body(size: 13, color: AppColors.accentGreen, weight: FontWeight.bold),
      ),
    ];
  }
}
