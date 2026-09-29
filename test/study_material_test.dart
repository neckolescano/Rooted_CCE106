import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/study_material.dart';

void main() {
  test('study material survives being saved and loaded back', () {
    const original = StudyMaterial(
      questions: [
        StudyQuestion(
          question: 'What is the powerhouse of the cell?',
          type: 'multiple_choice',
          answer: 'Mitochondria',
          choices: ['Nucleus', 'Mitochondria', 'Ribosome', 'Golgi body'],
          explanation: 'It makes energy (ATP).',
        ),
        StudyQuestion(question: 'The sun is a star.', type: 'true_false', answer: 'True', choices: ['True', 'False']),
        StudyQuestion(question: 'Process plants use to make food?', type: 'identification', answer: 'Photosynthesis'),
      ],
      flashcards: [Flashcard(front: 'Osmosis', back: 'Water moving across a membrane')],
      offline: true,
    );

    final restored = StudyMaterial.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(original.toJson())) as Map),
    );

    expect(restored.offline, isTrue);
    expect(restored.questions, hasLength(3));
    expect(restored.questions[0].choices, original.questions[0].choices);
    expect(restored.questions[0].answer, 'Mitochondria');
    expect(restored.questions[0].explanation, 'It makes energy (ATP).');
    expect(restored.questions[1].isTrueFalse, isTrue);
    expect(restored.questions[2].isMultipleChoice, isFalse);
    expect(restored.flashcards.single.back, 'Water moving across a membrane');
  });
}
