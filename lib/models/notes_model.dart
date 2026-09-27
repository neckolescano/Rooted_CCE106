import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import 'study_material.dart';

/// Holds the student's current notes and whatever study material has
/// been generated from them. Lives at the app root (like PlantModel and
/// SessionModel) so navigating Timer → Notes → Study Material → back
/// never loses anything or resets state.
class NotesModel extends ChangeNotifier {
  String text = '';
  StudyMaterial? material;
  bool isGenerating = false;
  String? errorMessage;

  void loadFrom(String savedText) {
    text = savedText;
    notifyListeners();
  }

  void updateText(String value) {
    text = value;
    notifyListeners();
  }

  Future<void> generateStudyMaterial(AiService service) async {
    if (text.trim().isEmpty || isGenerating) return;

    isGenerating = true;
    errorMessage = null;
    notifyListeners();

    try {
      material = await service.generateStudyMaterial(text);
    } catch (error) {
      errorMessage = error.toString();
      material = null;
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
