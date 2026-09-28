import 'dart:async';
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../models/study_material.dart';
import 'study_material_prompt.dart';

/// Thrown when study material generation fails, with a message that's
/// safe to show directly in the UI.
class AiServiceException implements Exception {
  AiServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Turns a student's notes into study questions and flashcards using
/// Gemini through Firebase AI Logic.
///
/// Why this is safe without a backend: the app never holds an AI API
/// key. Requests go to Firebase, which holds the credentials on its
/// side, and App Check makes sure only your real app can use it.
class AiService {
  // If Google retires this model you'll get an error mentioning it —
  // change this one line to a newer Flash model listed at
  // https://firebase.google.com/docs/ai-logic/models
  static const _modelName = 'gemini-3.8-flash';

  static const _friendlyMessage =
      'Something went wrong while creating your study material. Please try again.';

  /// Asks App Check for a token first and prints what happened. This
  /// doesn't stop the request (the server decides), it just leaves a
  /// clear trail in the Debug Console when something is wrong.
  Future<void> _logAppCheckStatus() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken().timeout(const Duration(seconds: 15));
      if (token == null || token.isEmpty) {
        debugPrint('[AI] App Check returned NO token. Register your debug token in the Firebase console.');
      } else {
        debugPrint('[AI] App Check token OK');
      }
    } on TimeoutException {
      debugPrint('[AI] App Check took over 15s to answer (network problem?)');
    } catch (error) {
      debugPrint('[AI] App Check failed: $error');
    }
  }

  Future<StudyMaterial> generateStudyMaterial(String notes) async {
    try {
      await _logAppCheckStatus();
      debugPrint('[AI] sending request to $_modelName');

      final model = FirebaseAI.googleAI().generativeModel(
        model: _modelName,
        // Asks Gemini to reply with raw JSON instead of prose.
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );

      final response = await model
          .generateContent([Content.text(buildStudyMaterialPrompt(notes))])
          .timeout(const Duration(seconds: 40));
      debugPrint('[AI] got a response');

      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw AiServiceException(_friendlyMessage);
      }
      return _parse(text);
    } on AiServiceException {
      rethrow;
    } on TimeoutException {
      debugPrint('[AI] request timed out after 40s');
      throw AiServiceException('This is taking too long. Check your connection and try again.');
    } catch (error) {
      debugPrint('Study material generation failed: $error');
      // While developing, show the real reason so problems (like App
      // Check not being set up yet) are easy to spot.
      throw AiServiceException(kDebugMode ? '$_friendlyMessage\n\n[debug] $error' : _friendlyMessage);
    }
  }

  /// Turns the model's reply into [StudyMaterial]. Tolerates the model
  /// wrapping the JSON in ```json fences, and treats a reply that
  /// isn't the expected shape as a normal (friendly) failure.
  StudyMaterial _parse(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '').replaceFirst(RegExp(r'\s*```$'), '');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw AiServiceException(_friendlyMessage);
    }
    if (decoded is! Map) throw AiServiceException(_friendlyMessage);

    final material = StudyMaterial.fromJson(Map<String, dynamic>.from(decoded));
    if (material.questions.isEmpty && material.flashcards.isEmpty) {
      throw AiServiceException(
        "I couldn't find enough in your notes to make study material. Try adding a bit more detail.",
      );
    }
    return material;
  }
}