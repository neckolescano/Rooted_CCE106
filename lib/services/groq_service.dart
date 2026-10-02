import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// The backup study AI: Groq (https://console.groq.com), called directly
/// over HTTPS — NOT through Firebase AI Logic.
///
/// Used only when no Gemini model answers (busy, out of quota, too slow).
///
/// The key comes from `groq.local.json` (git-ignored), passed at build time:
///   --dart-define-from-file=groq.local.json
/// No key → Groq is simply skipped. Note: unlike Firebase AI Logic, this
/// key ends up inside the APK, so someone determined could pull it out.
/// Fine for class testing; before a Play Store release, move the call
/// behind a small proxy server that holds the key.
class GroqService {
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  /// Models to try, in order (each has its own free quota). If Groq
  /// retires one, swap in a name from https://console.groq.com/docs/models
  static const _models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];

  /// Whether a key was passed in at build time.
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Sends [prompt] and returns the raw reply text (JSON), or null if
  /// Groq couldn't answer. Never throws — it's the backup, so a failure
  /// here just moves on to the offline maker.
  static Future<String?> ask(String prompt, {required int maxTokens, required Duration timeout}) async {
    if (!isConfigured) return null;
    for (final model in _models) {
      try {
        final stopwatch = Stopwatch()..start();
        debugPrint('[AI] sending request to Groq $model');
        final text = await _post(model, prompt, maxTokens).timeout(timeout);
        debugPrint('[AI] got a response from Groq $model in ${stopwatch.elapsed.inSeconds}s');
        if (text != null && text.trim().isNotEmpty) return text;
      } catch (error) {
        debugPrint('[AI] Groq $model failed: $error');
      }
    }
    return null;
  }

  static Future<String?> _post(String model, String prompt, int maxTokens) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(_url));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      request.add(utf8.encode(jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        // Reply with raw JSON (the prompt already describes the shape).
        'response_format': {'type': 'json_object'},
        'max_tokens': maxTokens,
        'temperature': 0.7,
      })));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        // 429 = this model's free quota is used up → the next model is tried.
        throw HttpException('Groq [${response.statusCode}] $body');
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['choices']?[0]?['message']?['content'] as String?;
    } finally {
      client.close();
    }
  }
}
