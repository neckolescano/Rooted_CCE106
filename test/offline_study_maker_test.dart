import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/study_options.dart';
import 'package:rooted/services/offline_study_maker.dart';

void main() {
  const notes = '''
## Human-Computer Interaction
Usability testing is a method where real users perform tasks while designers observe.
Accessibility means the system can be used by people with different abilities.
Feedback: the system response that tells users what happened after an action.
A successful HCI system should allow users to accomplish their goals effectively, efficiently, and comfortably.
''';

  test('makes flashcards and questions from definitions and key words', () {
    final material = OfflineStudyMaker.make(notes)!;

    expect(material.offline, isTrue);
    expect(material.flashcards.map((c) => c.front), containsAll(['Usability testing', 'Accessibility', 'Feedback']));
    expect(material.questions, isNotEmpty);

    // Multiple choice: the right answer is always one of the choices.
    for (final q in material.questions.where((q) => q.isMultipleChoice)) {
      expect(q.choices, contains(q.answer));
      expect(q.choices!.length, greaterThanOrEqualTo(2));
    }
    // Fill in the blank: the answer was blanked out of the question.
    for (final q in material.questions.where((q) => !q.isMultipleChoice)) {
      expect(q.question, contains('_____'));
      expect(q.answer, isNotEmpty);
    }
  });

  test('follows the chosen options: true/false only, counts, questions only', () {
    const options = StudyOptions(make: StudyMake.questionsOnly, questionCount: 5, style: QuestionStyle.trueFalse);
    final material = OfflineStudyMaker.make(notes, options)!;

    expect(material.flashcards, isEmpty); // questions only
    expect(material.questions.length, lessThanOrEqualTo(5));
    final trueFalse = material.questions.where((q) => q.isTrueFalse).toList();
    expect(trueFalse, isNotEmpty);
    for (final q in trueFalse) {
      expect(q.choices, ['True', 'False']);
      expect(['True', 'False'], contains(q.answer));
    }
  });

  test('options survive saving and loading, bad values fall back to defaults', () {
    const options = StudyOptions(
      make: StudyMake.flashcardsOnly,
      questionCount: 15,
      flashcardCount: 20,
      style: QuestionStyle.identification,
      difficulty: StudyDifficulty.hard,
    );
    final loaded = StudyOptions.fromJson(options.toJson());
    expect(loaded.make, StudyMake.flashcardsOnly);
    expect(loaded.flashcardCount, 20);
    expect(loaded.style, QuestionStyle.identification);
    expect(loaded.difficulty, StudyDifficulty.hard);

    final junk = StudyOptions.fromJson({'questionCount': 999, 'style': 'nonsense'});
    expect(junk.questionCount, 5);
    expect(junk.style, QuestionStyle.mixed);
  });

  test('gives up (null) when the notes are too short', () {
    expect(OfflineStudyMaker.make('hi'), isNull);
  });

  test('same notes give the same result every time', () {
    final a = OfflineStudyMaker.make(notes)!;
    final b = OfflineStudyMaker.make(notes)!;
    expect(a.questions.map((q) => q.choices), b.questions.map((q) => q.choices));
  });
}
