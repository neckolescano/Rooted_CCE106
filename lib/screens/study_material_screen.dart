import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notes_model.dart';
import '../models/study_material.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_timer_header.dart';
import '../widgets/flashcard_widget.dart';
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
  final Map<int, String> _selectedChoices = {};

  @override
  Widget build(BuildContext context) {
    final material = context.watch<NotesModel>().material;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  Text('Study Material', style: AppTheme.pixelHeading(size: 15)),
                ],
              ),
              const SizedBox(height: 4),
              const CompactTimerHeader(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _tabButton('Questions', !_showFlashcards, () => setState(() => _showFlashcards = false))),
                  const SizedBox(width: 8),
                  Expanded(child: _tabButton('Flashcards', _showFlashcards, () => setState(() => _showFlashcards = true))),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: material == null
                    ? Center(child: Text('No study material yet.', style: AppTheme.body(size: 13)))
                    : (_showFlashcards ? _buildFlashcards(material.flashcards) : _buildQuestions(material.questions)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.panelMedium : AppColors.panelMedium.withOpacity(0.25),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.panelDark, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTheme.body(size: 12, color: AppColors.textCream, weight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildQuestions(List<StudyQuestion> questions) {
    if (questions.isEmpty) {
      return Center(child: Text('No questions were generated.', style: AppTheme.body(size: 13)));
    }
    return ListView.separated(
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return StudyQuestionCard(
          question: questions[index],
          selectedChoice: _selectedChoices[index],
          onSelectChoice: (choice) => setState(() => _selectedChoices[index] = choice),
        );
      },
    );
  }

  Widget _buildFlashcards(List<Flashcard> cards) {
    if (cards.isEmpty) {
      return Center(child: Text('No flashcards were generated.', style: AppTheme.body(size: 13)));
    }
    final card = cards[_flashcardIndex];

    return Column(
      children: [
        Expanded(
          child: Center(
            child: FlashcardWidget(
              flashcard: card,
              flipped: _flashcardFlipped,
              onTap: () => setState(() => _flashcardFlipped = !_flashcardFlipped),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _flashcardIndex == 0
                  ? null
                  : () => setState(() {
                        _flashcardIndex--;
                        _flashcardFlipped = false;
                      }),
              child: const Text('Previous'),
            ),
            Text('${_flashcardIndex + 1} / ${cards.length}', style: AppTheme.body(size: 12, weight: FontWeight.bold)),
            TextButton(
              onPressed: _flashcardIndex >= cards.length - 1
                  ? null
                  : () => setState(() {
                        _flashcardIndex++;
                        _flashcardFlipped = false;
                      }),
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }
}
