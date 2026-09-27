import 'study_material_prompt.dart';
import '../models/study_material.dart';

/// Thrown when study material generation fails, with a message that's
/// safe to show directly in the UI.
class AiServiceException implements Exception {
  AiServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns a student's notes into study questions and flashcards.
///
/// IMPORTANT — this is intentionally NOT connected to a real AI
/// provider yet. Calling an AI API directly from a Flutter app would
/// mean embedding a secret API key inside the compiled app, which
/// anyone could pull back out — that's exactly what your own spec
/// said not to do. So instead of faking it with a hardcoded key, this
/// throws a clear, honest error explaining that a backend still needs
/// to be wired up.
///
/// Everything downstream of this (loading state, the error UI with a
/// Retry button, and parsing a JSON response into [StudyMaterial]) is
/// already built and working — this is the one seam left to connect
/// once you've decided how you want to host the actual API key
/// (a small serverless function, your own backend, Firebase, etc).
/// When that's ready, replace the body of [generateStudyMaterial] with
/// a real HTTP call to YOUR backend (never directly to the AI
/// provider), for example:
///
/// ```dart
/// final response = await http.post(
///   Uri.parse('https://your-backend.example.com/generate'),
///   headers: {'Content-Type': 'application/json'},
///   body: jsonEncode({'notes': notes}),
/// );
/// return StudyMaterial.fromJson(jsonDecode(response.body));
/// ```
///
/// [buildStudyMaterialPrompt] in `study_material_prompt.dart` already
/// has the exact prompt text your backend should send to the AI model.
class AiService {
  Future<StudyMaterial> generateStudyMaterial(String notes) async {
    // Kept here so it's obvious this is where the real request will go,
    // and so the prompt builder isn't unused/dead code in the meantime.
    // ignore: unused_local_variable
    final prompt = buildStudyMaterialPrompt(notes);

    await Future.delayed(const Duration(milliseconds: 500));

    throw AiServiceException(
      "Study material generation isn't connected to a backend yet — "
      "see lib/services/ai_service.dart for what to wire up.",
    );
  }
}
