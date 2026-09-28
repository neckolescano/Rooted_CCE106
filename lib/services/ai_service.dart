import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../models/study_material.dart';
import 'ai_firebase.dart';
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

  /// How long to wait for Gemini before giving up.
  static const _requestTimeout = Duration(seconds: 45);

  /// How long to wait for an App Check token before giving up.
  static const _appCheckTimeout = Duration(seconds: 10);

  Future<StudyMaterial> generateStudyMaterial(String notes) async {
    try {
      // 1. App Check. If the project ENFORCES it, requests without a valid
      //    token are rejected — so check first and leave a clear trail in
      //    the Debug Console. We still try the request either way (it
      //    works without a token while enforcement is off); if Firebase
      //    then rejects it, _explain() turns that into the App Check hint.
      await _checkAppCheckToken();

      // 2. Ask Gemini.
      debugPrint('[AI] sending request to $_modelName (project ${AiFirebase.app.options.projectId})');
      final model = FirebaseAI.googleAI(app: AiFirebase.app).generativeModel(
        model: _modelName,
        // Asks Gemini to reply with raw JSON instead of prose.
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );
      final stopwatch = Stopwatch()..start();
      final response = await model
          .generateContent([Content.text(buildStudyMaterialPrompt(notes))])
          .timeout(_requestTimeout);
      debugPrint('[AI] got a response in ${stopwatch.elapsed.inSeconds}s');

      // 3. Turn the reply into questions + flashcards.
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw AiServiceException('The garden companion came back empty-handed. Try again?');
      }
      return _parse(text);
    } on AiServiceException {
      rethrow;
    } on TimeoutException {
      debugPrint('[AI] request timed out after ${_requestTimeout.inSeconds}s');
      throw AiServiceException(
        "This is taking too long — your internet may be slow. Try again on Wi-Fi or a stronger signal.",
      );
    } catch (error) {
      debugPrint('[AI] generation failed: $error');
      throw AiServiceException(_explain(error));
    }
  }

  Future<void> _checkAppCheckToken() async {
    try {
      final token = await AiFirebase.appCheck.getToken().timeout(_appCheckTimeout);
      if (token == null || token.isEmpty) {
        debugPrint('[AI] App Check returned NO token — requests will fail if App Check is enforced. '
            'Register the app + debug token (AI_SETUP.md).');
      } else {
        debugPrint('[AI] App Check token OK');
      }
    } on TimeoutException {
      debugPrint('[AI] App Check took over ${_appCheckTimeout.inSeconds}s (slow network?) — trying anyway');
    } catch (error) {
      debugPrint('[AI] App Check failed: $error — trying anyway');
    }
  }

  /// The most common setup problem while developing.
  String _appCheckMessage(Object? error) {
    const friendly = "The study AI can't verify this app yet, so it won't answer.";
    if (kReleaseMode) return '$friendly Please try again later.';
    return '$friendly\n\n'
        '[developer] Register this phone\'s App Check debug token in the Firebase console '
        '(App Check → Apps → your Android app → ⋮ → Manage debug tokens). See AI_SETUP.md.'
        '${error == null ? '' : '\n[debug] $error'}';
  }

  /// Turns a raw error into something a student can act on. Debug builds
  /// also get the real error underneath, to make fixing things easy.
  String _explain(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    final String message;

    if (error is SocketException || lower.contains('failed host lookup') || lower.contains('network')) {
      message = "You seem to be offline. Connect to the internet and try again.";
    } else if (lower.contains('app check') || lower.contains('app-check') || lower.contains('appcheck')) {
      return _appCheckMessage(error);
    } else if (lower.contains('denied access')) {
      // Google has restricted this Firebase project's access to the free
      // Gemini API — common for school/academic accounts. Not an app bug.
      message = "The study AI isn't available for this app's account right now.";
      if (!kReleaseMode) {
        return '$message\n\n[developer] Google blocked Gemini API access for this Firebase project '
            '("project denied access"). Use a project owned by a personal Google account, '
            'or request a review. See AI_SETUP.md.\n[debug] $raw';
      }
    } else if (lower.contains('quota') || lower.contains('429') || lower.contains('resource_exhausted')) {
      message = "The study AI is busy right now (too many requests). Wait a minute and try again.";
    } else if (lower.contains('permission') || lower.contains('403') || lower.contains('api has not been used') ||
        lower.contains('service_disabled') || lower.contains('not enabled')) {
      message = "The study AI isn't switched on for this app yet.";
      if (!kReleaseMode) {
        return '$message\n\n[developer] In the Firebase console: AI Services → AI Logic → Get started → '
            'Gemini Developer API. If it\'s already on, check App Check (AI_SETUP.md).\n[debug] $raw';
      }
    } else if (lower.contains('not found') && lower.contains('model')) {
      message = "The AI model this app uses isn't available anymore.";
      if (!kReleaseMode) {
        return "$message\n\n[developer] Change _modelName in lib/services/ai_service.dart "
            "(see firebase.google.com/docs/ai-logic/models).\n[debug] $raw";
      }
    } else if (lower.contains('safety') || lower.contains('blocked')) {
      message = "The AI couldn't use these notes. Try rewording or trimming them.";
    } else {
      message = 'Something went wrong while creating your study material. Please try again.';
    }
    return kReleaseMode ? message : '$message\n\n[debug] $raw';
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
      debugPrint('[AI] reply was not valid JSON: ${text.length > 200 ? '${text.substring(0, 200)}…' : text}');
      throw AiServiceException("The garden companion's answer got scrambled. Try again?");
    }
    if (decoded is! Map) throw AiServiceException("The garden companion's answer got scrambled. Try again?");

    final material = StudyMaterial.fromJson(Map<String, dynamic>.from(decoded));
    if (material.questions.isEmpty && material.flashcards.isEmpty) {
      throw AiServiceException(
        "I couldn't find enough in your notes to make study material. Try adding a bit more detail.",
      );
    }
    debugPrint('[AI] made ${material.questions.length} questions and ${material.flashcards.length} flashcards');
    return material;
  }
}
