import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../models/study_material.dart';
import '../models/study_options.dart';
import 'ai_firebase.dart';
import 'offline_study_maker.dart';
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
  /// Models to try, in order. If one is overloaded, out of free quota, or
  /// too slow, the next one is used. All are stable models from
  /// https://firebase.google.com/docs/ai-logic/models — if Google retires
  /// one, swap in a newer name from that page.
  ///
  /// Flash-Lite goes first: on the free tier the bigger/newer Flash models
  /// have a tiny daily quota (they returned "429 quota exceeded" in
  /// testing), while gemini-3.1-flash-lite answered this exact request in
  /// ~6 s. Questions + flashcards from notes don't need the bigger model.
  static const _models = ['gemini-3.1-flash-lite', 'gemini-3.5-flash-lite', 'gemini-3.5-flash', 'gemini-3.8-flash'];

  /// Attempts per model when it says it's busy (with a short pause between).
  static const _triesPerModel = 2;

  /// How long to wait for one Gemini reply before giving up — more items
  /// take longer to write (5+5 items → 30 s, 20+20 → 60 s).
  static Duration _requestTimeout(StudyOptions o) => Duration(seconds: 20 + o.totalItems);

  /// Total time allowed across all retries/models before using the
  /// offline backup instead.
  static Duration _totalBudget(StudyOptions o) => Duration(seconds: 50 + o.totalItems);

  /// Room for the reply: ~250 tokens per item, at least 2048, at most 8192.
  static int _maxOutputTokens(StudyOptions o) => (1024 + o.totalItems * 250).clamp(2048, 8192);

  /// How long to wait for an App Check token before giving up.
  static const _appCheckTimeout = Duration(seconds: 10);

  /// [options] = the choices from the "Grow your study patch" scroll.
  Future<StudyMaterial> generateStudyMaterial(String notes, [StudyOptions options = const StudyOptions()]) async {
    try {
      // 1. App Check. If the project ENFORCES it, requests without a valid
      //    token are rejected — so check first and leave a clear trail in
      //    the Debug Console. We still try the request either way (it
      //    works without a token while enforcement is off); if Firebase
      //    then rejects it, _explain() turns that into the App Check hint.
      await _checkAppCheckToken();

      // 2. Ask Gemini — retrying / switching model while it's busy, within
      //    a total time budget.
      final prompt = buildStudyMaterialPrompt(notes, options);
      debugPrint('[AI] asking for ${options.wantsQuestions ? options.questionCount : 0} questions '
          '(${options.style.name}, ${options.difficulty.name}) + '
          '${options.wantsFlashcards ? options.flashcardCount : 0} flashcards');
      final clock = Stopwatch()..start();
      for (final modelName in _models) {
        for (var attempt = 1; attempt <= _triesPerModel; attempt++) {
          if (clock.elapsed > _totalBudget(options)) break;
          try {
            final text = await _ask(modelName, prompt, options);
            // 3. Turn the reply into questions + flashcards, trimmed to
            //    exactly what the student asked for.
            return _fit(_parse(text), options);
          } on AiServiceException {
            rethrow; // e.g. empty/garbled reply — not worth retrying
          } on TimeoutException {
            // Some models hang on the free tier while others answer fast —
            // don't wait again, move on to the next model.
            debugPrint('[AI] $modelName took over ${_requestTimeout(options).inSeconds}s — trying the next model');
            break;
          } catch (error) {
            final busy = _busyKind(error);
            if (busy == null) rethrow; // a real problem (App Check, blocked…) — explain it
            debugPrint('[AI] $modelName is busy ($busy), attempt $attempt of $_triesPerModel');
            if (busy == 'quota') break; // this model's free quota is used up → next model
            if (attempt < _triesPerModel) await Future<void>.delayed(Duration(seconds: 2 * attempt));
          }
        }
      }
      debugPrint('[AI] no model answered in time (${clock.elapsed.inSeconds}s)');
      return _offlineOr(notes, options, 'The study AI is very busy right now. Wait a minute and try again.');
    } on AiServiceException {
      rethrow;
    } on TimeoutException {
      debugPrint('[AI] request timed out after ${_requestTimeout(options).inSeconds}s');
      return _offlineOr(
        notes,
        options,
        "This is taking too long — your internet may be slow. Try again on Wi-Fi or a stronger signal.",
      );
    } catch (error) {
      debugPrint('[AI] generation failed: $error');
      if (_isOffline(error)) {
        return _offlineOr(notes, options, 'You seem to be offline. Connect to the internet and try again.');
      }
      throw AiServiceException(_explain(error));
    }
  }

  /// Drops what wasn't asked for and anything beyond the requested counts
  /// (the AI sometimes adds a bonus item or two).
  StudyMaterial _fit(StudyMaterial m, StudyOptions o) {
    final fitted = StudyMaterial(
      questions: o.wantsQuestions ? m.questions.take(o.questionCount).toList() : const [],
      flashcards: o.wantsFlashcards ? m.flashcards.take(o.flashcardCount).toList() : const [],
    );
    debugPrint('[AI] kept ${fitted.questions.length} questions and ${fitted.flashcards.length} flashcards');
    return fitted;
  }

  /// The AI couldn't answer in time (busy / slow / offline): make simpler
  /// study material on the phone instead, so the student always gets
  /// something. Only if the notes are too short for that, show [message].
  StudyMaterial _offlineOr(String notes, StudyOptions options, String message) {
    final backup = OfflineStudyMaker.make(notes, options);
    if (backup == null) throw AiServiceException(message);
    debugPrint('[AI] using the offline backup: ${backup.questions.length} questions, '
        '${backup.flashcards.length} flashcards');
    return backup;
  }

  bool _isOffline(Object error) {
    final lower = error.toString().toLowerCase();
    return error is SocketException || lower.contains('failed host lookup') || lower.contains('network');
  }

  /// One request to one model. Returns the raw reply text.
  Future<String> _ask(String modelName, String prompt, StudyOptions options) async {
    debugPrint('[AI] sending request to $modelName (project ${AiFirebase.app.options.projectId})');
    final model = FirebaseAI.googleAI(app: AiFirebase.app).generativeModel(
      model: modelName,
      generationConfig: GenerationConfig(
        // Reply with raw JSON instead of prose.
        responseMimeType: 'application/json',
        // (No thinkingConfig: Flash-Lite's default was fastest in testing —
        // 6 s vs 13 s with "low" thinking.)
        // Room for the requested number of items; caps runaway replies.
        maxOutputTokens: _maxOutputTokens(options),
      ),
    );
    final stopwatch = Stopwatch()..start();
    final response = await model.generateContent([Content.text(prompt)]).timeout(_requestTimeout(options));
    debugPrint('[AI] got a response from $modelName in ${stopwatch.elapsed.inSeconds}s');
    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw AiServiceException('The garden companion came back empty-handed. Try again?');
    }
    return text;
  }

  /// 'busy' for temporary overload, 'quota' for used-up free quota,
  /// null for anything else (a real problem that retrying won't fix).
  String? _busyKind(Object error) {
    final lower = error.toString().toLowerCase();
    if (lower.contains('quota') || lower.contains('429') || lower.contains('resource_exhausted')) return 'quota';
    if (lower.contains('high demand') ||
        lower.contains('overloaded') ||
        lower.contains('unavailable') ||
        lower.contains('[500]') ||
        lower.contains('[503]') ||
        lower.contains('"internal"')) {
      return 'busy';
    }
    return null;
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
