import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../models/study_material.dart';
import '../theme/app_theme.dart';
import 'pixel_button.dart';
import 'pixel_icon_button.dart';
import 'pixel_panel.dart';
import 'pixel_progress_bar.dart';
import 'study_question_card.dart';

/// The Study Patch questions as a quiz: one question at a time with a
/// progress bar and score, Next / Finish, then a results page with
/// "Review missed", "Practice again" and "See all answers".
///
/// The first run is the real one: its first tries are kept on NotesModel
/// (they survive leaving the patch, and the secret "perfect patch" is
/// checked against them). Review and practice runs keep their own answers,
/// so they never change the score or the secret.
class StudyQuiz extends StatefulWidget {
  const StudyQuiz({super.key, required this.questions, required this.onFirstTry});

  final List<StudyQuestion> questions;

  /// Called once per question on the real run's first try.
  final void Function(int index, bool correct) onFirstTry;

  @override
  State<StudyQuiz> createState() => _StudyQuizState();
}

class _StudyQuizState extends State<StudyQuiz> {
  // A review / practice run: which questions (by index), where we are, and
  // its own answers. null = the real run.
  List<int>? _practice;
  int _practiceAt = 0;
  int _practiceRun = 0; // new run = fresh question cards
  final Map<int, bool> _practiceResult = {};
  final Map<int, String> _practiceChosen = {};

  bool _showAll = false;

  void _startPractice(List<int> indices) => setState(() {
        _practice = indices;
        _practiceRun++;
        _practiceAt = 0;
        _practiceResult.clear();
        _practiceChosen.clear();
      });

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesModel>();
    final questions = widget.questions;
    final firstTry = notes.firstTry;

    if (_showAll) return _allAnswers(notes);

    final practice = _practice;
    if (practice != null) {
      if (_practiceAt >= practice.length) return _practiceResults(practice);
      final index = practice[_practiceAt];
      return _questionView(
        key: ValueKey('practice-$_practiceRun-$index'),
        position: _practiceAt,
        count: practice.length,
        right: _practiceResult.values.where((ok) => ok).length,
        question: questions[index],
        answered: _practiceResult.containsKey(index),
        chosen: _practiceChosen[index],
        onChoose: (choice) => setState(() => _practiceChosen[index] = choice),
        onAnswered: (correct) => setState(() => _practiceResult.putIfAbsent(index, () => correct)),
        onPrev: _practiceAt == 0 ? null : () => setState(() => _practiceAt--),
        onNext: () => setState(() => _practiceAt++),
        label: 'PRACTICE',
      );
    }

    final at = notes.quizIndex.clamp(0, questions.length);
    if (at >= questions.length) return _results(firstTry);
    return _questionView(
      key: ValueKey('quiz-$at'),
      position: at,
      count: questions.length,
      right: firstTry.values.where((ok) => ok).length,
      question: questions[at],
      answered: firstTry.containsKey(at),
      chosen: notes.chosenAnswers[at],
      onChoose: (choice) => setState(() => notes.chosenAnswers[at] = choice),
      onAnswered: (correct) {
        widget.onFirstTry(at, correct);
        setState(() {});
      },
      onPrev: at == 0 ? null : () => setState(() => notes.quizIndex = at - 1),
      onNext: () => setState(() => notes.quizIndex = at + 1),
      label: 'QUESTION',
    );
  }

  /// One question: a header with the count, score and progress bar, the
  /// question card, and Prev / Next underneath. Next unlocks once answered.
  Widget _questionView({
    required Key key,
    required int position,
    required int count,
    required int right,
    required StudyQuestion question,
    required bool answered,
    required String? chosen,
    required ValueChanged<String> onChoose,
    required ValueChanged<bool> onAnswered,
    required VoidCallback? onPrev,
    required VoidCallback onNext,
    required String label,
  }) {
    final last = position == count - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelPanel(
          style: PanelStyle.dark,
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('$label ${position + 1} / $count', style: AppText.caption(color: AppColors.textCream)),
                  ),
                  Text('✓ $right', style: AppText.caption(color: AppColors.accentGold)),
                ],
              ),
              const SizedBox(height: 6),
              PixelProgressBar(
                value: (position + (answered ? 1 : 0)) / count,
                height: 10,
                semanticLabel: 'Quiz progress',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: SingleChildScrollView(
            child: StudyQuestionCard(
              key: key,
              question: question,
              answered: answered,
              selectedChoice: chosen,
              onSelectChoice: onChoose,
              onAnswered: onAnswered,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            PixelIconButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Previous question',
              style: PanelStyle.dark,
              onPressed: onPrev,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PixelButton(
                label: last ? 'Finish' : 'Next',
                icon: last ? Icons.flag : Icons.arrow_forward,
                height: 52,
                // Answer first — revealing the answer counts too.
                onPressed: answered ? onNext : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The real run's score, with the next steps.
  Widget _results(Map<int, bool> firstTry) {
    final total = widget.questions.length;
    final right = firstTry.values.where((ok) => ok).length;
    final missed = [for (var i = 0; i < total; i++) if (firstTry[i] != true) i];
    final pct = total == 0 ? 0 : (right * 100 / total).round();
    final message = pct >= 90
        ? 'Amazing! Your knowledge is in full bloom! 🌸'
        : pct >= 70
            ? 'Great job! Your garden is growing strong. 🌿'
            : pct >= 50
                ? "Nice work! A little more watering and you'll bloom. 🌱"
                : 'Every expert started as a seed. Review and try again! 🌰';

    return ListView(
      children: [
        PixelPanel(
          style: PanelStyle.parchment,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text('QUIZ COMPLETE!', style: AppText.caption(color: AppColors.panelMedium).copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.sm),
              Text('$right / $total', style: AppTheme.pixelHeading(size: 40, color: AppColors.greenDeep)),
              const SizedBox(height: 4),
              Text('$pct% right on the first try', style: AppText.small(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.md),
              Text(message, textAlign: TextAlign.center, style: AppTheme.body(size: 14, weight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (missed.isNotEmpty) ...[
          PixelButton(
            label: 'Review missed (${missed.length})',
            icon: Icons.replay,
            onPressed: () => _startPractice(missed),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        PixelButton(
          label: 'Practice again',
          icon: Icons.refresh,
          tone: ButtonTone.secondary,
          height: 48,
          onPressed: () => _startPractice([for (var i = 0; i < total; i++) i]),
        ),
        const SizedBox(height: AppSpacing.sm),
        PixelButton(
          label: 'See all answers',
          icon: Icons.list,
          tone: ButtonTone.secondary,
          height: 48,
          onPressed: () => setState(() => _showAll = true),
        ),
      ],
    );
  }

  Widget _practiceResults(List<int> practice) {
    final right = _practiceResult.values.where((ok) => ok).length;
    return ListView(
      children: [
        PixelPanel(
          style: PanelStyle.parchment,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Text('PRACTICE DONE', style: AppText.caption(color: AppColors.panelMedium).copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.sm),
              Text('$right / ${practice.length}', style: AppTheme.pixelHeading(size: 40, color: AppColors.greenDeep)),
              const SizedBox(height: AppSpacing.md),
              Text(
                right == practice.length ? 'You got them all this time! 🌸' : 'Keep at it, every try helps it stick. 🌱',
                textAlign: TextAlign.center,
                style: AppTheme.body(size: 14, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PixelButton(
          label: 'Back to results',
          icon: Icons.arrow_back,
          onPressed: () => setState(() => _practice = null),
        ),
      ],
    );
  }

  /// Every question with its answer, to look back over.
  Widget _allAnswers(NotesModel notes) {
    final questions = widget.questions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => StudyQuestionCard(
              number: i + 1,
              total: questions.length,
              question: questions[i],
              answered: true,
              selectedChoice: notes.chosenAnswers[i],
              onSelectChoice: (_) {},
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PixelButton(
          label: 'Back to results',
          icon: Icons.arrow_back,
          height: 48,
          onPressed: () => setState(() => _showAll = false),
        ),
      ],
    );
  }
}
