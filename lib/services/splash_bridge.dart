import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to MainActivity.kt ("kuwago/splash") so the opening continues
/// seamlessly from the phone's animated splash (Android 12+).
class SplashBridge {
  SplashBridge._();

  static const _channel = MethodChannel('kuwago/splash');

  /// Where the splash drew kuwago (centre of the splash icon, in logical
  /// pixels), or null when there's no splash to continue from (older
  /// Android, hot restart, web preview…).
  static Future<Offset?> handoff() async {
    try {
      final r = await _channel
          .invokeMapMethod<String, Object?>('iconCenter')
          .timeout(const Duration(milliseconds: 1500));
      if (r == null) return null;
      return Offset((r['x'] as num).toDouble(), (r['y'] as num).toDouble());
    } catch (error) {
      debugPrint('[Intro] no splash hand-off ($error)');
      return null;
    }
  }

  /// Removes the splash (after its animation has finished), revealing the
  /// identical Flutter frame underneath.
  static Future<void> remove() async {
    try {
      await _channel.invokeMethod<void>('remove').timeout(const Duration(seconds: 3));
    } catch (_) {
      // Nothing to remove, or it's already gone.
    }
  }
}
