import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import 'study_material.dart';
import 'study_options.dart';

/// Holds the student's current notes and whatever study material has
/// been generated from them. Lives at the app root (like PlantModel and
/// SessionModel) so navigating Timer → Notes → Study Material → back
/// never loses anything or resets state.
class NotesModel extends ChangeNotifier {
  String text = '';
  StudyMaterial? material;
  bool isGenerating = false;
  String? errorMessage;

  /// While a big patch grows in batches: items ready so far / asked for
  /// (0 / 0 until the first batch is back).
  int progressMade = 0;
  int progressTotal = 0;

  /// A friendly heads-up about the last patch, e.g. when the notes only
  /// had enough for 32 of the 50 questions asked for.
  String? notice;

  /// Called with each newly generated study material so it gets saved —
  /// even if the Notes screen was closed while the AI was working (e.g.
  /// the timer ended). Set once at start-up (see main.dart).
  void Function(StudyMaterial material)? onGenerated;

  // Answers given in the Study Patch, kept here (not on the screen) so
  // leaving the patch and coming back doesn't forget them. They belong to
  // one set of material and start over when new material arrives.
  final Map<int, bool> _firstTry = {};
  final Map<int, String> _chosen = {};
  StudyMaterial? _answersFor;
  int _quizIndex = 0;

  void _matchAnswersToMaterial() {
    if (identical(_answersFor, material)) return;
    _firstTry.clear();
    _chosen.clear();
    _quizIndex = 0;
    _answersFor = material;
  }

  /// Which quiz question is showing (questions.length = the results page),
  /// so leaving the Study Patch and coming back continues where you were.
  int get quizIndex {
    _matchAnswersToMaterial();
    return _quizIndex;
  }

  set quizIndex(int value) {
    _matchAnswersToMaterial();
    _quizIndex = value;
  }

  /// Question index → answered right on the FIRST try (the secret
  /// "perfect patch" is checked against this).
  Map<int, bool> get firstTry {
    _matchAnswersToMaterial();
    return _firstTry;
  }

  /// Question index → the multiple-choice answer picked.
  Map<int, String> get chosenAnswers {
    _matchAnswersToMaterial();
    return _chosen;
  }

  void loadFrom(String savedText, {StudyMaterial? savedMaterial}) {
    text = savedText;
    material = savedMaterial;
    notifyListeners();
  }

  void updateText(String value) {
    text = value;
    notifyListeners();
  }

  Future<void> generateStudyMaterial(AiService service, StudyOptions options) async {
    if (text.trim().isEmpty || isGenerating) return;

    isGenerating = true;
    errorMessage = null;
    notice = null;
    progressMade = 0;
    progressTotal = 0;
    notifyListeners();

    try {
      final generated = await service.generateStudyMaterial(text, options, (made, total) {
        progressMade = made;
        progressTotal = total;
        notifyListeners();
      });
      material = generated;
      notice = _shortNotice(generated, options);
      onGenerated?.call(generated);
    } catch (error) {
      // Keep the previously saved material — a failed try shouldn't lose it.
      errorMessage = error.toString();
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  /// "Your notes had enough for 32 of the 50 questions." when fewer came
  /// back than asked for (short notes, or the AI got busy halfway).
  static String? _shortNotice(StudyMaterial m, StudyOptions o) {
    if (m.offline) return null; // the offline banner already explains it
    final parts = <String>[];
    if (o.wantsQuestions && m.questions.length < o.questionCount) {
      parts.add('${m.questions.length} of the ${o.questionCount} questions');
    }
    if (o.wantsFlashcards && m.flashcards.length < o.flashcardCount) {
      parts.add('${m.flashcards.length} of the ${o.flashcardCount} flashcards');
    }
    if (parts.isEmpty) return null;
    return 'Your notes had enough for ${parts.join(' and ')}. Add more notes to grow a bigger patch.';
  }

  /// Wipes everything — used when someone signs out so the next person
  /// to log in doesn't see this user's notes or study material.
  void reset() {
    text = '';
    material = null;
    errorMessage = null;
    notice = null;
    isGenerating = false;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
