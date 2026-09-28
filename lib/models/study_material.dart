/// One flashcard — a term/question on the front, the answer on the back.
class Flashcard {
  const Flashcard({required this.front, required this.back});

  final String front;
  final String back;

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      front: json['front']?.toString() ?? '',
      back: json['back']?.toString() ?? '',
    );
  }
}

/// One study question. `type` is usually "multiple_choice" or
/// "short_answer" — `choices` is only present for multiple choice.
class StudyQuestion {
  const StudyQuestion({
    required this.question,
    required this.type,
    required this.answer,
    this.choices,
    this.explanation,
  });

  final String question;
  final String type;
  final String answer;
  final List<String>? choices;
  final String? explanation;

  bool get isMultipleChoice => type == 'multiple_choice' && choices != null && choices!.isNotEmpty;

  factory StudyQuestion.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    final choices = rawChoices is List ? rawChoices.map((e) => e.toString()).toList() : null;
    return StudyQuestion(
      question: json['question']?.toString() ?? '',
      type: json['type']?.toString() ?? 'short_answer',
      answer: _matchAnswerToChoice(json['answer']?.toString() ?? '', choices),
      choices: choices,
      explanation: json['explanation']?.toString(),
    );
  }
}

/// The AI sometimes answers a multiple choice question with "B" or with
/// slightly different capitalisation instead of the exact choice text,
/// which would make a correct pick look wrong. This snaps the answer to
/// the matching choice when it can.
String _matchAnswerToChoice(String answer, List<String>? choices) {
  if (choices == null || choices.isEmpty || choices.contains(answer)) return answer;

  final trimmed = answer.trim();
  for (final choice in choices) {
    if (choice.trim().toLowerCase() == trimmed.toLowerCase()) return choice;
  }

  final letter = RegExp(r'^\(?([A-Za-z])[\).:]?$').firstMatch(trimmed);
  if (letter != null) {
    final index = letter.group(1)!.toUpperCase().codeUnitAt(0) - 'A'.codeUnitAt(0);
    if (index >= 0 && index < choices.length) return choices[index];
  }
  return answer;
}

/// The full set of AI-generated material for one batch of notes.
class StudyMaterial {
  const StudyMaterial({required this.questions, required this.flashcards});

  final List<StudyQuestion> questions;
  final List<Flashcard> flashcards;

  /// Parses the JSON shape the AI prompt asks for. Missing or malformed
  /// sections are just treated as empty lists rather than throwing, so
  /// a partially-broken response still shows whatever DID come through
  /// correctly instead of failing the whole thing.
  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    final rawFlashcards = json['flashcards'];

    final questions = rawQuestions is List
        ? rawQuestions
            .whereType<Map>()
            .map((e) => StudyQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <StudyQuestion>[];

    final flashcards = rawFlashcards is List
        ? rawFlashcards
            .whereType<Map>()
            .map((e) => Flashcard.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Flashcard>[];

    return StudyMaterial(questions: questions, flashcards: flashcards);
  }
}
