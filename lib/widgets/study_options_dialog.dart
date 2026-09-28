import 'package:flutter/material.dart';
import '../models/study_options.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_dialog.dart';
import 'pixel_panel.dart';

/// "Grow your study patch" — choose what the AI makes from your notes.
/// Returns the chosen options, or null if closed with "Not now".
Future<StudyOptions?> showStudyOptions(BuildContext context, StudyOptions initial) {
  return showDialog<StudyOptions>(
    context: context,
    barrierColor: AppColors.overlay,
    builder: (_) => _StudyOptionsDialog(initial: initial),
  );
}

class _StudyOptionsDialog extends StatefulWidget {
  const _StudyOptionsDialog({required this.initial});

  final StudyOptions initial;

  @override
  State<_StudyOptionsDialog> createState() => _StudyOptionsDialogState();
}

class _StudyOptionsDialogState extends State<_StudyOptionsDialog> {
  late StudyOptions _o = widget.initial;

  void _set(StudyOptions o) => setState(() => _o = o);

  @override
  Widget build(BuildContext context) {
    final bigRequest = _o.totalItems >= 25;

    return PixelDialog(
      title: 'Grow your study patch',
      sealIcon: Icons.auto_awesome,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            label: 'MAKE',
            child: _Choices<StudyMake>(
              values: StudyMake.values,
              selected: _o.make,
              label: (v) => v.label,
              onPick: (v) => _set(_o.copyWith(make: v)),
            ),
          ),
          if (_o.wantsQuestions) ...[
            _Section(
              label: 'QUESTIONS',
              child: _Choices<int>(
                values: StudyOptions.counts,
                selected: _o.questionCount,
                label: (v) => '$v',
                onPick: (v) => _set(_o.copyWith(questionCount: v)),
              ),
            ),
            _Section(
              label: 'QUESTION STYLE',
              child: _Choices<QuestionStyle>(
                values: QuestionStyle.values,
                selected: _o.style,
                label: (v) => v.label,
                onPick: (v) => _set(_o.copyWith(style: v)),
              ),
            ),
          ],
          if (_o.wantsFlashcards)
            _Section(
              label: 'FLASHCARDS',
              child: _Choices<int>(
                values: StudyOptions.counts,
                selected: _o.flashcardCount,
                label: (v) => '$v',
                onPick: (v) => _set(_o.copyWith(flashcardCount: v)),
              ),
            ),
          _Section(
            label: 'DIFFICULTY',
            child: _Choices<StudyDifficulty>(
              values: StudyDifficulty.values,
              selected: _o.difficulty,
              label: (v) => v.label,
              onPick: (v) => _set(_o.copyWith(difficulty: v)),
            ),
          ),
          Text(
            bigRequest
                ? '⏳ Big patch! This can take up to a minute to grow.'
                : 'Short notes may give fewer items — the AI only uses what\'s in your notes.',
            textAlign: TextAlign.center,
            style: AppText.caption(color: bigRequest ? AppColors.panelMedium : AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        PixelButton(
          label: 'Grow Study Material',
          icon: Icons.auto_awesome,
          onPressed: () => Navigator.of(context).pop(_o),
        ),
        PixelButton(
          label: 'Not now',
          tone: ButtonTone.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption(color: AppColors.panelMedium).copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// A row (wrapping) of pick-one wooden chips.
class _Choices<T> extends StatelessWidget {
  const _Choices({required this.values, required this.selected, required this.label, required this.onPick});

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          Semantics(
            button: true,
            selected: v == selected,
            label: label(v),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onPick(v),
              child: PixelPanel(
                style: v == selected ? PanelStyle.wood : PanelStyle.parchment,
                outlineColor: v == selected ? AppColors.accentGold : null,
                sunken: v != selected,
                shadow: false,
                expand: false,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Text(
                  label(v),
                  style: AppTheme.body(
                    size: 12,
                    color: v == selected ? AppColors.textCream : AppColors.textDark,
                    weight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
