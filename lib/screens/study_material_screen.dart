import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../models/plant_catalog.dart';
import '../models/secrets.dart';
import '../models/study_material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_timer_header.dart';
import '../widgets/desk_background.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/pixel_icon_button.dart';
import '../widgets/pixel_panel.dart';
import '../widgets/secret_found_dialog.dart';
import '../widgets/study_question_card.dart';

class StudyMaterialScreen extends StatefulWidget {
  const StudyMaterialScreen({super.key});

  @override
  State<StudyMaterialScreen> createState() => _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends State<StudyMaterialScreen> {
  bool _showFlashcards = false;
  int _flashcardIndex = 0;
  bool _flashcardFlipped = false;

  static const _shadowedCream = [Shadow(offset: Offset(0, 2), color: Color(0x99000000))];

  @override
  void initState() {
    super.initState();
    // Open on the tab that has something in it — e.g. "Flashcards only"
    // used to open on an empty Questions tab, which looked like a failure.
    final material = context.read<NotesModel>().material;
    _showFlashcards = material != null && material.questions.isEmpty && material.flashcards.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final material = context.watch<NotesModel>().material;

    return Scaffold(
      backgroundColor: AppColors.panelMedium,
      body: DeskBackground(
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PixelIconButton(
                      icon: Icons.arrow_back,
                      semanticLabel: 'Back to your journal',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Study Patch',
                        style: AppText.screenTitle(color: AppColors.textCream).copyWith(shadows: _shadowedCream),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const CompactTimerHeader(),
                if (material?.offline ?? false) ...[
                  // Made by OfflineStudyMaker because the AI was busy/slow.
                  PixelPanel(
                    style: PanelStyle.parchment,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off, size: 18, color: AppColors.panelMedium),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Made offline — the study AI was busy. Generate again later for smarter questions.',
                            style: AppText.small(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _Tab(
                        label: 'Questions',
                        icon: Icons.quiz,
                        selected: !_showFlashcards,
                        onTap: () => setState(() => _showFlashcards = false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Tab(
                        label: 'Flashcards',
                        icon: Icons.style,
                        selected: _showFlashcards,
                        onTap: () => setState(() => _showFlashcards = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: material == null
                      ? _emptyMessage('No study material yet.')
                      : (_showFlashcards ? _buildFlashcards(material.flashcards) : _buildQuestions(material.questions)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) {
    return Center(
      child: PixelPanel(
        style: PanelStyle.parchment,
        expand: false,
        child: Text(text, style: AppText.body()),
      ),
    );
  }

  /// Secret: every question right on the first try (at least
  /// [Secrets.perfectPatchMinQuestions]) reveals kuwago's own flower.
  /// First tries are kept on NotesModel, so they survive leaving the patch.
  Future<void> _recordFirstTry(int index, bool correct, int total) async {
    final firstTry = context.read<NotesModel>().firstTry..putIfAbsent(index, () => correct);
    if (total < Secrets.perfectPatchMinQuestions || firstTry.length < total) return;
    if (firstTry.values.any((ok) => !ok)) return;
    final storage = context.read<StorageService>();
    if (!await storage.unlockSecret(Secrets.perfectPatch) || !mounted) return;
    await showSecretSeedFound(context, plantCatalog.firstWhere((s) => s.secret == Secrets.perfectPatch));
  }

  Widget _buildQuestions(List<StudyQuestion> questions) {
    if (questions.isEmpty) return _emptyMessage('No questions were generated.');

    final notes = context.read<NotesModel>();
    return ListView.separated(
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return StudyQuestionCard(
          number: index + 1,
          total: questions.length,
          question: questions[index],
          answered: notes.firstTry.containsKey(index),
          selectedChoice: notes.chosenAnswers[index],
          onSelectChoice: (choice) => setState(() => notes.chosenAnswers[index] = choice),
          onAnswered: (correct) => _recordFirstTry(index, correct, questions.length),
        );
      },
    );
  }

  Widget _buildFlashcards(List<Flashcard> cards) {
    if (cards.isEmpty) return _emptyMessage('No flashcards were generated.');
    final card = cards[_flashcardIndex];

    void goTo(int index) => setState(() {
          _flashcardIndex = index;
          _flashcardFlipped = false;
        });

    return Column(
      children: [
        Expanded(
          child: Center(
            child: FlashcardWidget(
              // New key per card so the flip animation resets instead of
              // animating from the previous card's side.
              key: ValueKey(_flashcardIndex),
              flashcard: card,
              flipped: _flashcardFlipped,
              onTap: () => setState(() => _flashcardFlipped = !_flashcardFlipped),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            PixelIconButton(
              icon: Icons.arrow_back,
              label: 'PREV',
              semanticLabel: 'Previous card',
              style: PanelStyle.dark,
              onPressed: _flashcardIndex == 0 ? null : () => goTo(_flashcardIndex - 1),
            ),
            Expanded(
              child: Text(
                '${_flashcardIndex + 1} / ${cards.length}',
                textAlign: TextAlign.center,
                style: AppTheme.pixelHeading(size: 12, color: AppColors.textCream).copyWith(shadows: _shadowedCream),
              ),
            ),
            PixelIconButton(
              icon: Icons.arrow_forward,
              label: 'NEXT',
              semanticLabel: 'Next card',
              style: PanelStyle.dark,
              onPressed: _flashcardIndex >= cards.length - 1 ? null : () => goTo(_flashcardIndex + 1),
            ),
          ],
        ),
      ],
    );
  }
}

/// Questions | Flashcards switch. Selected = wood slot with gold outline
/// (same as the bottom nav), unselected = dark plank.
class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textCream : AppColors.textCream.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PixelPanel(
          style: selected ? PanelStyle.wood : PanelStyle.dark,
          outlineColor: selected ? AppColors.accentGold : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? AppColors.accentGold : color),
              const SizedBox(width: 6),
              Text(label.toUpperCase(), style: AppText.panelTitle(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
