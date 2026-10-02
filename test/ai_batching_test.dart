// A big Study Patch (more than 20 items) is made in batches.
import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/notes_model.dart';
import 'package:rooted/models/study_material.dart';
import 'package:rooted/models/study_options.dart';
import 'package:rooted/services/ai_service.dart';

/// A stand-in for Gemini: answers each batch with new numbered items,
/// but never more than [notesHave] questions in total (short notes).
class FakeAi {
  FakeAi({this.notesHave = 1000, this.failOnBatch});

  final int notesHave;
  final int? failOnBatch;
  final prompts = <String>[];
  int made = 0;

  Future<StudyMaterial?> call(String prompt, StudyOptions o) async {
    prompts.add(prompt);
    if (prompts.length == failOnBatch) throw Exception('busy');
    final count = o.wantsQuestions ? o.questionCount.clamp(0, notesHave - made) : 0;
    final questions = [
      for (var i = 0; i < count; i++)
        StudyQuestion(question: 'Question ${made + i + 1}?', type: 'identification', answer: 'A${made + i + 1}'),
    ];
    made += count;
    final cards = o.wantsFlashcards
        ? [for (var i = 0; i < o.flashcardCount; i++) Flashcard(front: 'Card ${prompts.length}-$i', back: 'B')]
        : <Flashcard>[];
    return StudyMaterial(questions: questions, flashcards: cards);
  }
}

const fifty = StudyOptions(make: StudyMake.questionsOnly, questionCount: 50);

void main() {
  test('50 questions are made in batches of 20, 20 and 10, without repeats', () async {
    final ai = FakeAi();
    final progress = <int>[];
    final m = await AiService(askBatchForTest: ai.call).generateStudyMaterial('notes', fifty, (made, _) => progress.add(made));
    expect(m.questions, hasLength(50));
    expect(ai.prompts, hasLength(3));
    expect(progress, [20, 40, 50]);
    // Later batches are told what already exists.
    expect(ai.prompts[0], isNot(contains('ALREADY made')));
    expect(ai.prompts[1], contains('ALREADY made'));
    expect(ai.prompts[1], contains('- Question 20?'));
    expect(m.questions.map((q) => q.question).toSet(), hasLength(50));
  });

  test('stops early when the notes run out', () async {
    final ai = FakeAi(notesHave: 32);
    final m = await AiService(askBatchForTest: ai.call).generateStudyMaterial('notes', fifty);
    expect(m.questions, hasLength(32));
    expect(ai.prompts, hasLength(2)); // no third request
  });

  test('a later batch failing keeps what was already made', () async {
    final ai = FakeAi(failOnBatch: 2);
    final m = await AiService(askBatchForTest: ai.call).generateStudyMaterial('notes', fifty);
    expect(m.questions, hasLength(20));
  });

  test('repeated items from the AI are dropped', () async {
    var calls = 0;
    Future<StudyMaterial?> repeating(String prompt, StudyOptions o) async {
      calls++;
      return StudyMaterial(
        questions: [
          for (var i = 0; i < o.questionCount; i++)
            StudyQuestion(question: calls == 1 ? 'Q$i' : 'q${i % 3}', type: 'identification', answer: 'a'),
        ],
        flashcards: const [],
      );
    }

    final m = await AiService(askBatchForTest: repeating)
        .generateStudyMaterial('notes', const StudyOptions(make: StudyMake.questionsOnly, questionCount: 30));
    expect(m.questions.map((q) => q.question).toSet(), hasLength(m.questions.length));
  });

  test('repeats are replaced by asking again, not treated as the notes running out', () async {
    // Like on the phone: batch 2 repeats 10 earlier flashcards.
    var calls = 0;
    var nextCard = 0;
    Future<StudyMaterial?> ai(String prompt, StudyOptions o) async {
      calls++;
      final cards = [
        for (var i = 0; i < o.flashcardCount; i++)
          Flashcard(front: calls == 2 && i < 10 ? 'Card $i' : 'Card ${nextCard++}', back: 'B'),
      ];
      return StudyMaterial(questions: const [], flashcards: cards);
    }

    final m = await AiService(askBatchForTest: ai)
        .generateStudyMaterial('notes', const StudyOptions(make: StudyMake.flashcardsOnly, flashcardCount: 50));
    expect(m.flashcards, hasLength(50));
    expect(m.flashcards.map((f) => f.front).toSet(), hasLength(50));
    expect(calls, 3); // batch 3 asks for all 20 still missing, repeats included
  });

  test('small patches are still one request', () async {
    final ai = FakeAi();
    final m = await AiService(askBatchForTest: ai.call)
        .generateStudyMaterial('notes', const StudyOptions(questionCount: 20, flashcardCount: 20));
    expect(ai.prompts, hasLength(1));
    expect(m.questions, hasLength(20));
    expect(m.flashcards, hasLength(20));
  });

  test('the journal says when the notes had fewer than asked for', () async {
    final notes = NotesModel()..text = 'some notes';
    await notes.generateStudyMaterial(AiService(askBatchForTest: FakeAi(notesHave: 32).call), fifty);
    expect(notes.material!.questions, hasLength(32));
    expect(notes.notice, contains('32 of the 50 questions'));
    expect(notes.progressTotal, 50);
  });
}
