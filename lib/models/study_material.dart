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
    return StudyQuestion(
      question: json['question']?.toString() ?? '',
      type: json['type']?.toString() ?? 'short_answer',
      answer: json['answer']?.toString() ?? '',
      choices: rawChoices is List ? rawChoices.map((e) => e.toString()).toList() : null,
      explanation: json['explanation']?.toString(),
    );
  }
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
