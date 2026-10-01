import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  AiService({@visibleForTesting this.askBatchForTest});

  /// Tests only: answers each batch instead of Gemini (see test/ai_batching_test.dart).
  final Future<StudyMaterial?> Function(String prompt, StudyOptions options)? askBatchForTest;

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
  ///
  /// A big patch (more than [StudyOptions.batchSize] questions or
  /// flashcards) is made in batches; [onProgress] reports how many items
  /// are ready so far. If a later batch fails, or the notes run out, the
  /// student keeps everything made up to then.
  Future<StudyMaterial> generateStudyMaterial(
    String notes, [
    StudyOptions options = const StudyOptions(),
    void Function(int made, int total)? onProgress,
  ]) async {
    try {
      // 1. App Check. If the project ENFORCES it, requests without a valid
      //    token are rejected — so check first and leave a clear trail in
      //    the Debug Console. We still try the request either way (it
      //    works without a token while enforcement is off); if Firebase
      //    then rejects it, _explain() turns that into the App Check hint.
      if (askBatchForTest == null) _appCheckOk = await _checkAppCheckToken();

      // 2. Ask Gemini, one batch at a time.
      final wantQ = options.wantsQuestions ? options.questionCount : 0;
      final wantF = options.wantsFlashcards ? options.flashcardCount : 0;
      final questions = <StudyQuestion>[];
      final flashcards = <Flashcard>[];
      for (var batch = 1; questions.length < wantQ || flashcards.length < wantF; batch++) {
        final askQ = min(wantQ - questions.length, StudyOptions.batchSize);
        final askF = min(wantF - flashcards.length, StudyOptions.batchSize);
        final ask = options.copyWith(
          make: askQ == 0 ? StudyMake.flashcardsOnly : (askF == 0 ? StudyMake.questionsOnly : StudyMake.both),
          questionCount: max(askQ, 1),
          flashcardCount: max(askF, 1),
        );
        final alreadyMade = [for (final q in questions) q.question, for (final f in flashcards) f.front];
        debugPrint('[AI] batch $batch: asking for $askQ questions '
            '(${options.style.name}, ${options.difficulty.name}) + $askF flashcards');

        final StudyMaterial? got;
        try {
          got = await (askBatchForTest ?? _askWithRetries)(buildStudyMaterialPrompt(notes, ask, alreadyMade), ask);
        } catch (error) {
          if (batch == 1) rethrow; // nothing made yet: explain it / go offline
          debugPrint('[AI] batch $batch failed, keeping what was made: $error');
          break;
        }
        if (got == null) {
          if (batch == 1) {
            return _offlineOr(notes, options, 'The study AI is very busy right now. Wait a minute and try again.');
          }
          break; // keep the earlier batches
        }

        // Add only new items (the AI can still repeat itself now and then).
        final seenQ = {for (final q in questions) _key(q.question)};
        final seenF = {for (final f in flashcards) _key(f.front)};
        final newQ = got.questions.where((q) => seenQ.add(_key(q.question))).take(askQ).toList();
        final newF = got.flashcards.where((f) => seenF.add(_key(f.front))).take(askF).toList();
        questions.addAll(newQ);
        flashcards.addAll(newF);
        onProgress?.call(questions.length + flashcards.length, wantQ + wantF);

        // The AI sending back fewer than asked = the notes have nothing more
        // to ask about. (Repeats it sent are dropped above and simply asked
        // for again in the next batch — that's not the notes running out.)
        if (got.questions.length < askQ || got.flashcards.length < askF) {
          debugPrint('[AI] the notes ran out after batch $batch');
          break;
        }
        if (newQ.isEmpty && newF.isEmpty) break; // only repeats: stop asking
        if (batch >= _maxBatches(wantQ, wantF)) {
          debugPrint('[AI] stopping after $batch batches (too many repeats)');
          break;
        }
      }
      debugPrint('[AI] kept ${questions.length} questions and ${flashcards.length} flashcards');
      return StudyMaterial(questions: questions, flashcards: flashcards);
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

  /// One batch: asks Gemini, retrying / switching model while it's busy,
  /// within a time budget. null = no model answered in time.
  Future<StudyMaterial?> _askWithRetries(String prompt, StudyOptions options) async {
    final clock = Stopwatch()..start();
    for (final modelName in _models) {
      for (var attempt = 1; attempt <= _triesPerModel; attempt++) {
        if (clock.elapsed > _totalBudget(options)) break;
        try {
          final text = await _ask(modelName, prompt, options);
          final m = _parse(text);
          // Drop what wasn't asked for (the AI sometimes adds extras).
          return StudyMaterial(
            questions: options.wantsQuestions ? m.questions : const [],
            flashcards: options.wantsFlashcards ? m.flashcards : const [],
          );
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
    return null;
  }

  /// The batches a patch needs, plus one spare to replace repeats (so a
  /// repeating AI can't use up the daily quota).
  static int _maxBatches(int wantQ, int wantF) => (max(wantQ, wantF) / StudyOptions.batchSize).ceil() + 1;

  /// For spotting repeats: lower case, letters and digits only.
  static String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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
    // Without a working App Check token the AI library won't send anything,
    // so fall back to the connection that skips App Check (test installs).
    final app = _appCheckOk ? AiFirebase.app : await AiFirebase.appWithoutAppCheck();
    debugPrint('[AI] sending request to $modelName (project ${app.options.projectId}'
        '${_appCheckOk ? '' : ', without App Check'})');
    final model = FirebaseAI.googleAI(app: app).generativeModel(
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

  /// Whether the last App Check check produced a usable token.
  bool _appCheckOk = true;

  /// true = App Check gave a token (use the protected connection).
  Future<bool> _checkAppCheckToken() async {
    try {
      final token = await AiFirebase.appCheck.getToken().timeout(_appCheckTimeout);
      if (token == null || token.isEmpty) {
        debugPrint('[AI] App Check returned NO token — requests will fail if App Check is enforced. '
            'Register the app + debug token (AI_SETUP.md).');
        return false;
      }
      debugPrint('[AI] App Check token OK');
      return true;
    } on TimeoutException {
      debugPrint('[AI] App Check took over ${_appCheckTimeout.inSeconds}s (slow network?) — trying without it');
    } catch (error) {
      // e.g. "App attestation failed" on test installs (not from the Play Store).
      debugPrint('[AI] App Check failed: $error — trying without it');
    }
    return false;
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
