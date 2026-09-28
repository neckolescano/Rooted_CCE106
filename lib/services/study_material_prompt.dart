import '../models/study_options.dart';

/// Builds the prompt that turns a student's notes into study material,
/// following the choices from the "Grow your study patch" scroll.
String buildStudyMaterialPrompt(String notes, [StudyOptions options = const StudyOptions()]) {
  final parts = <String>[];

  if (options.wantsQuestions) {
    parts.add('- "questions": exactly ${options.questionCount} study questions. ${_styleRule(options.style)}');
  } else {
    parts.add('- "questions": an empty list [].');
  }
  if (options.wantsFlashcards) {
    parts.add('- "flashcards": exactly ${options.flashcardCount} flashcards '
        '(front = a key term or short question, back = the answer or a short explanation).');
  } else {
    parts.add('- "flashcards": an empty list [].');
  }

  return '''
You are a study assistant. Create study material based ONLY on the student's notes below.

Make:
${parts.join('\n')}

Difficulty: ${_difficultyRule(options.difficulty)}

Rules:
- Do not invent facts that are not supported by the notes. If the notes are too short for the requested amount, make fewer items rather than making things up.
- Do not repeat the same fact in two questions or two flashcards.
- Keep every answer, choice and explanation short (one sentence at most).
- Each question has: "question", "type", "answer", "explanation" (one short sentence based on the notes), and "choices" ONLY for "multiple_choice" and "true_false".
- For "multiple_choice": 4 choices, and "answer" must be word-for-word identical to one of the choices.
- For "true_false": "question" is a statement, "choices" is exactly ["True", "False"], and "answer" is "True" or "False".
- For "identification": the answer is a single term or short phrase from the notes.

Respond with ONLY valid JSON in exactly this shape, with no extra commentary:

{
  "questions": [
    {"question": "...", "type": "multiple_choice", "choices": ["...", "...", "...", "..."], "answer": "...", "explanation": "..."},
    {"question": "...", "type": "true_false", "choices": ["True", "False"], "answer": "True", "explanation": "..."},
    {"question": "...", "type": "identification", "answer": "...", "explanation": "..."}
  ],
  "flashcards": [
    {"front": "...", "back": "..."}
  ]
}

Student notes:
$notes
''';
}

String _styleRule(QuestionStyle style) => switch (style) {
      QuestionStyle.mixed =>
        'Use a mix of types: mostly "multiple_choice", plus some "true_false" and "identification".',
      QuestionStyle.multipleChoice => 'Every question has type "multiple_choice".',
      QuestionStyle.trueFalse => 'Every question has type "true_false".',
      QuestionStyle.identification =>
        'Every question has type "identification" (the student types the answer).',
    };

String _difficultyRule(StudyDifficulty difficulty) => switch (difficulty) {
      StudyDifficulty.easy =>
        'EASY — ask directly about key terms and definitions, with clearly different wrong choices.',
      StudyDifficulty.normal => 'NORMAL — check understanding of the main ideas, not just memorised words.',
      StudyDifficulty.hard =>
        'HARD — test deeper understanding: comparisons, cause and effect, applying ideas to examples, '
            'with plausible wrong choices.',
    };
