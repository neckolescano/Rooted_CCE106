import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options_ai.dart';

/// The Firebase connection the AI features use.
///
/// If [aiFirebaseOptions] is filled in, the AI talks to that separate
/// project (with its own App Check); otherwise it falls back to the main
/// project. Login, Firestore and everything else always use the main one.
class AiFirebase {
  AiFirebase._();

  static const _appName = 'ai';

  /// The project AI requests go to.
  static FirebaseApp get app =>
      Firebase.apps.any((a) => a.name == _appName) ? Firebase.app(_appName) : Firebase.app();

  static FirebaseAppCheck get appCheck => FirebaseAppCheck.instanceFor(app: app);

  /// Call once at start-up, after the main Firebase app + App Check.
  /// Uses the same App Check provider (and debug token) as the main app —
  /// register that token in the AI project too.
  static Future<void> init(AndroidAppCheckProvider provider) async {
    const options = aiFirebaseOptions;
    if (options == null) {
      debugPrint('[AI] No separate AI project configured — using the main project.');
      return;
    }
    try {
      final aiApp = await Firebase.initializeApp(name: _appName, options: options);
      await FirebaseAppCheck.instanceFor(app: aiApp).activate(providerAndroid: provider);
      debugPrint('[AI] Using separate AI project "${options.projectId}".');
    } catch (error) {
      debugPrint('[AI] Could not start the AI project (${options.projectId}): $error');
    }
  }
}
