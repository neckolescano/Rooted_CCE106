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

  void _matchAnswersToMaterial() {
    if (identical(_answersFor, material)) return;
    _firstTry.clear();
    _chosen.clear();
    _answersFor = material;
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
    notifyListeners();

    try {
      final generated = await service.generateStudyMaterial(text, options);
      material = generated;
      onGenerated?.call(generated);
    } catch (error) {
      // Keep the previously saved material — a failed try shouldn't lose it.
      errorMessage = error.toString();
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  /// Wipes everything — used when someone signs out so the next person
  /// to log in doesn't see this user's notes or study material.
  void reset() {
    text = '';
    material = null;
    errorMessage = null;
    isGenerating = false;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
