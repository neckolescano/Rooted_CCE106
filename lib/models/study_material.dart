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

/// One study question. `type` is "multiple_choice", "true_false"
/// (choices True/False) or "identification"/"short_answer" (typed answer,
/// no choices).
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

  /// Shown as tappable choices (multiple choice AND true/false).
  bool get isMultipleChoice =>
      (type == 'multiple_choice' || type == 'true_false') && choices != null && choices!.isNotEmpty;

  bool get isTrueFalse => type == 'true_false';

  factory StudyQuestion.fromJson(Map<String, dynamic> json) {
    final rawChoices = json['choices'];
    final type = json['type']?.toString() ?? 'short_answer';
    var choices = rawChoices is List ? rawChoices.map((e) => e.toString()).toList() : null;
    // True/false without choices (the AI forgot them) → add them.
    if (type == 'true_false' && (choices == null || choices.isEmpty)) choices = const ['True', 'False'];
    return StudyQuestion(
      question: json['question']?.toString() ?? '',
      type: type,
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
  const StudyMaterial({required this.questions, required this.flashcards, this.offline = false});

  final List<StudyQuestion> questions;
  final List<Flashcard> flashcards;

  /// true = made on the phone by OfflineStudyMaker because the AI was
  /// busy/slow/offline (simpler questions). The screen says so.
  final bool offline;

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
