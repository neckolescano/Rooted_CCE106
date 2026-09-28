import 'dart:math';
import '../models/study_material.dart';
import '../models/study_options.dart';

/// Makes simple study material from notes WITHOUT the internet or AI —
/// the backup used when Gemini is busy, slow, or the phone is offline.
///
/// It looks for:
///   * definitions — "Photosynthesis is how plants make food."
///                   "Chlorophyll: the green pigment in leaves"
///     → flashcards (term → meaning) and multiple choice questions
///       (the other definitions become the wrong answers)
///   * key words in other sentences → fill-in-the-blank questions
///
/// It's simpler than the AI, but students always get something to study.
/// It follows the student's choices (what to make, how many, style) as
/// far as the notes allow.
class OfflineStudyMaker {
  OfflineStudyMaker._();

  /// null if the notes are too short to make anything useful.
  static StudyMaterial? make(String notes, [StudyOptions options = const StudyOptions()]) {
    final sentences = _sentences(notes);
    if (sentences.isEmpty) return null;
    final maxFlashcards = options.wantsFlashcards ? options.flashcardCount : 0;
    final maxQuestions = options.wantsQuestions ? options.questionCount : 0;
    final style = options.style;

    // Same notes → same questions (and same shuffled choices) every time.
    final random = Random(notes.hashCode);

    final definitions = <_Definition>[];
    final others = <String>[];
    for (final s in sentences) {
      final d = _definitionIn(s);
      if (d != null) {
        definitions.add(d);
      } else {
        others.add(s);
      }
    }

    // Flashcards: definitions first, then fill-in-the-blank cards.
    final flashcards = <Flashcard>[
      for (final d in definitions.take(maxFlashcards)) Flashcard(front: d.term, back: d.meaning),
    ];
    for (final s in others) {
      if (flashcards.length >= maxFlashcards) break;
      final blank = _blankOut(s);
      if (blank != null) flashcards.add(Flashcard(front: blank.question, back: s));
    }

    final questions = <StudyQuestion>[];

    // True/False: "Term is (its own meaning)" = True, "Term is (another
    // term's meaning)" = False, alternating. Needs 2+ definitions.
    if (style == QuestionStyle.trueFalse && definitions.length >= 2) {
      for (var i = 0; i < definitions.length && questions.length < maxQuestions; i++) {
        final d = definitions[i];
        final makeFalse = i.isOdd;
        final other = definitions[(i + 1) % definitions.length];
        final meaning = makeFalse ? other.meaning : d.meaning;
        questions.add(StudyQuestion(
          question: '${d.term} ${d.verb} ${_lowerFirst(meaning)}.',
          type: 'true_false',
          answer: makeFalse ? 'False' : 'True',
          choices: const ['True', 'False'],
          explanation: '${d.term} ${d.verb} ${_lowerFirst(d.meaning)}.',
        ));
      }
    }

    // Multiple choice from definitions (needs 2+ so there are wrong
    // answers to choose from). "Mixed" uses up to half its questions here.
    final wantsMultipleChoice = style == QuestionStyle.multipleChoice || style == QuestionStyle.mixed;
    if (wantsMultipleChoice && definitions.length >= 2) {
      final limit = style == QuestionStyle.mixed ? (maxQuestions + 1) ~/ 2 : maxQuestions;
      for (final d in definitions) {
        if (questions.length >= limit) break;
        final wrong = definitions.where((o) => o != d).map((o) => o.meaning).toList()..shuffle(random);
        final choices = [d.meaning, ...wrong.take(3)]..shuffle(random);
        questions.add(StudyQuestion(
          question: 'What ${d.verb} ${d.term.toLowerCase()}?',
          type: 'multiple_choice',
          answer: d.meaning,
          choices: choices,
          explanation: '${d.term} ${d.verb} ${_lowerFirst(d.meaning)}.',
        ));
      }
    }

    // Fill in the blank (identification) for the rest — also the fallback
    // when the notes don't have enough definitions for the chosen style.
    for (final s in [...others, ...definitions.map((d) => d.sentence)]) {
      if (questions.length >= maxQuestions) break;
      final blank = _blankOut(s);
      if (blank == null) continue;
      questions.add(StudyQuestion(
        question: 'Fill in the blank: ${blank.question}',
        type: 'identification',
        answer: blank.answer,
        explanation: s,
      ));
    }

    if (flashcards.isEmpty && questions.isEmpty) return null;
    return StudyMaterial(questions: questions, flashcards: flashcards, offline: true);
  }

  /// Notes → clean sentences (markdown bullets/headings removed).
  static List<String> _sentences(String notes) {
    final cleaned = notes
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\s*(#+|[-*•]|\d+[.)])\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
    return cleaned
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 15 && s.length <= 240)
        .toList();
  }

  static final _isPattern = RegExp(
    r'^(.{2,60}?)\s+(is|are|was|were|means|refers to)\s+(.{5,})$',
    caseSensitive: false,
  );
  static final _colonPattern = RegExp(r'^([^:]{2,40}):\s*(.{5,})$');

  static _Definition? _definitionIn(String sentence) {
    final s = sentence.replaceFirst(RegExp(r'[.!?]+$'), '');
    final colon = _colonPattern.firstMatch(s);
    if (colon != null) {
      return _Definition(_capitalize(colon.group(1)!.trim()), 'is', _capitalize(colon.group(2)!.trim()), sentence);
    }
    final m = _isPattern.firstMatch(s);
    if (m == null) return null;
    final term = m.group(1)!.trim();
    // Skip vague subjects ("It is…", "This is…") — they make bad cards.
    if (_vagueSubjects.contains(term.toLowerCase())) return null;
    return _Definition(_capitalize(term), m.group(2)!.toLowerCase(), _capitalize(m.group(3)!.trim()), sentence);
  }

  /// Hides the most important-looking word (the longest non-common word).
  static ({String question, String answer})? _blankOut(String sentence) {
    final words = RegExp(r"[A-Za-z][A-Za-z'-]{4,}").allMatches(sentence).map((m) => m.group(0)!).toList();
    final candidates = words.where((w) => !_stopWords.contains(w.toLowerCase())).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.length.compareTo(a.length));
    final answer = candidates.first;
    return (question: sentence.replaceFirst(answer, '_____'), answer: answer);
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  static String _lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  static const _vagueSubjects = {'it', 'this', 'that', 'there', 'they', 'these', 'those', 'he', 'she', 'which'};

  static const _stopWords = {
    'about', 'after', 'again', 'against', 'along', 'also', 'among', 'another', 'because', 'before', 'being',
    'below', 'between', 'could', 'during', 'every', 'first', 'from', 'having', 'however', 'important', 'into',
    'itself', 'might', 'other', 'others', 'should', 'since', 'something', 'still', 'their', 'there', 'these',
    'they', 'thing', 'things', 'those', 'through', 'under', 'until', 'using', 'usually', 'very', 'where',
    'which', 'while', 'within', 'without', 'would', 'people', 'always', 'often', 'called',
  };
}

class _Definition {
  _Definition(this.term, this.verb, this.meaning, this.sentence);

  final String term; // "Photosynthesis"
  final String verb; // "is"
  final String meaning; // "How plants make food"
  final String sentence; // the original sentence
}
