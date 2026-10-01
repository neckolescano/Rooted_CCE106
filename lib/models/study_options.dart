/// What to make.
enum StudyMake { both, questionsOnly, flashcardsOnly }

/// Question style.
enum QuestionStyle { mixed, multipleChoice, trueFalse, identification }

enum StudyDifficulty { easy, normal, hard }

/// The student's choices on the "Grow your study patch" scroll (picked
/// before generating). Saved, so the same choices come back next time.
class StudyOptions {
  const StudyOptions({
    this.make = StudyMake.both,
    this.questionCount = 5,
    this.flashcardCount = 5,
    this.style = QuestionStyle.mixed,
    this.difficulty = StudyDifficulty.normal,
  });

  /// The counts offered on the scroll. Above [batchSize] the AI makes them
  /// in batches (see AiService), so 50 questions still works.
  static const counts = [5, 10, 15, 20, 30, 40, 50];

  /// The most questions (and flashcards) asked for in ONE AI request —
  /// bigger replies get slow and can be cut off.
  static const batchSize = 20;

  final StudyMake make;
  final int questionCount;
  final int flashcardCount;
  final QuestionStyle style;
  final StudyDifficulty difficulty;

  bool get wantsQuestions => make != StudyMake.flashcardsOnly;
  bool get wantsFlashcards => make != StudyMake.questionsOnly;

  /// Total items asked for — used to give bigger requests more time.
  int get totalItems => (wantsQuestions ? questionCount : 0) + (wantsFlashcards ? flashcardCount : 0);

  /// Needs more than one AI request (see [batchSize]).
  bool get isBatched =>
      (wantsQuestions && questionCount > batchSize) || (wantsFlashcards && flashcardCount > batchSize);

  StudyOptions copyWith({
    StudyMake? make,
    int? questionCount,
    int? flashcardCount,
    QuestionStyle? style,
    StudyDifficulty? difficulty,
  }) {
    return StudyOptions(
      make: make ?? this.make,
      questionCount: questionCount ?? this.questionCount,
      flashcardCount: flashcardCount ?? this.flashcardCount,
      style: style ?? this.style,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, Object> toJson() => {
        'make': make.name,
        'questionCount': questionCount,
        'flashcardCount': flashcardCount,
        'style': style.name,
        'difficulty': difficulty.name,
      };

  /// Unknown / missing values fall back to the defaults (never throws).
  factory StudyOptions.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    int count(Object? v) => v is int && counts.contains(v) ? v : 5;
    return StudyOptions(
      make: pick(StudyMake.values, json['make'], StudyMake.both),
      questionCount: count(json['questionCount']),
      flashcardCount: count(json['flashcardCount']),
      style: pick(QuestionStyle.values, json['style'], QuestionStyle.mixed),
      difficulty: pick(StudyDifficulty.values, json['difficulty'], StudyDifficulty.normal),
    );
  }
}

// Labels shown on the scroll.
extension StudyMakeLabel on StudyMake {
  String get label => switch (this) {
        StudyMake.both => 'Both',
        StudyMake.questionsOnly => 'Questions',
        StudyMake.flashcardsOnly => 'Flashcards',
      };
}

extension QuestionStyleLabel on QuestionStyle {
  String get label => switch (this) {
        QuestionStyle.mixed => 'Mixed',
        QuestionStyle.multipleChoice => 'Multiple choice',
        QuestionStyle.trueFalse => 'True or False',
        QuestionStyle.identification => 'Identification',
      };
}

extension StudyDifficultyLabel on StudyDifficulty {
  String get label => switch (this) {
        StudyDifficulty.easy => 'Easy',
        StudyDifficulty.normal => 'Normal',
        StudyDifficulty.hard => 'Hard',
      };
}
