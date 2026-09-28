import 'package:flutter/material.dart';
import '../models/study_material.dart';
import '../theme/app_theme.dart';
import 'pixel_panel.dart';

/// One study question on a parchment card. Handles both shapes:
/// multiple choice (tap a choice to check it) and short answer (reveal
/// the answer on tap).
class StudyQuestionCard extends StatefulWidget {
  const StudyQuestionCard({
    super.key,
    required this.question,
    required this.selectedChoice,
    required this.onSelectChoice,
    this.number,
    this.total,
  });

  final StudyQuestion question;
  final String? selectedChoice;
  final ValueChanged<String> onSelectChoice;

  /// Optional "QUESTION 2 / 5" label.
  final int? number;
  final int? total;

  @override
  State<StudyQuestionCard> createState() => _StudyQuestionCardState();
}

class _StudyQuestionCardState extends State<StudyQuestionCard> {
  bool _revealed = false;

  // Answer tile colors. Correct/wrong also get a ✓/✗ icon, so the
  // result never depends on color alone.
  static const _correctFill = Color(0xFFD5E8BE);
  static const _wrongFill = Color(0xFFF2C9C1);

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final selected = widget.selectedChoice;
    final answeredCorrectly = selected != null && selected == q.answer;

    return PixelPanel(
      style: PanelStyle.parchment,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.number != null && widget.total != null) ...[
            Text(
              'QUESTION ${widget.number} / ${widget.total}',
              style: AppText.caption(color: AppColors.panelMedium).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
          ],
          Text(q.question, style: AppTheme.body(size: 15, weight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.md),
          if (q.isMultipleChoice) ..._buildChoices(q) else ..._buildShortAnswer(q),
          if (_revealed && q.isMultipleChoice && selected != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              answeredCorrectly ? 'CORRECT!  Your knowledge is growing!' : "NOT QUITE!  Let's learn this one again.",
              style: AppText.small(
                color: answeredCorrectly ? AppColors.greenDeep : AppColors.dangerText,
                weight: FontWeight.w900,
              ),
            ),
          ],
          if (_revealed && (q.explanation?.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(q.explanation!, style: AppText.small(color: AppColors.textMuted, weight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildChoices(StudyQuestion q) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final choices = q.choices!;

    return [
      for (var i = 0; i < choices.length; i++) _choiceTile(q, choices[i], i < letters.length ? letters[i] : '•'),
    ];
  }

  Widget _choiceTile(StudyQuestion q, String choice, String letter) {
    final isSelected = widget.selectedChoice == choice;
    final isCorrectChoice = choice == q.answer;

    Color? fill;
    Color? outline;
    IconData? mark;
    if (_revealed && isSelected) {
      fill = isCorrectChoice ? _correctFill : _wrongFill;
      outline = isCorrectChoice ? AppColors.greenDeep : AppColors.dangerText;
      mark = isCorrectChoice ? Icons.check : Icons.close;
    } else if (_revealed && isCorrectChoice) {
      // After a wrong pick, also show which one was right.
      outline = AppColors.greenDeep;
      mark = Icons.check;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: 'Option $letter: $choice',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.onSelectChoice(choice);
            setState(() => _revealed = true);
          },
          child: PixelPanel(
            style: PanelStyle.parchment,
            sunken: !isSelected,
            shadow: false,
            backgroundColor: fill ?? const Color(0xFFFBEBD3),
            outlineColor: outline,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                Text('$letter.', style: AppTheme.body(size: 14, color: AppColors.panelMedium, weight: FontWeight.w900)),
                const SizedBox(width: 10),
                Expanded(child: Text(choice, style: AppTheme.body(size: 14, weight: FontWeight.w600))),
                if (mark != null) Icon(mark, size: 18, color: outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildShortAnswer(StudyQuestion q) {
    if (!_revealed) {
      return [
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: () => setState(() => _revealed = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                'Reveal answer',
                style: AppText.small(color: AppColors.panelMedium, weight: FontWeight.w900)
                    .copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ),
      ];
    }
    return [
      Text(q.answer, style: AppTheme.body(size: 14, color: AppColors.greenDeep, weight: FontWeight.w800)),
    ];
  }
}
