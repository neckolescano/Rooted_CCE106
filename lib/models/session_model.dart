import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secrets.dart';

enum SessionStatus { idle, running, paused, completed, failed }

/// Runs the Pomodoro countdown and reports back whether the session
/// finished successfully or was given up on. TimerScreen listens to this
/// to update the clock, and reacts to completed/failed to grow or wilt
/// the plant.
///
/// It keeps the moment the session ENDS ([_endsAt]) rather than counting
/// seconds down, so the clock can't drift and is still right after the
/// phone sleeps or the app is in the background. The active session is
/// also saved on the phone, so if Android closes the app mid-session,
/// reopening it brings the student back to it — and a session that
/// finished while the app was closed still counts (see [restore]).
///
/// The length is chosen on the Home screen (the FOCUS TIME setter) and
/// passed to [start].
class SessionModel extends ChangeNotifier {
  SessionModel({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;
  static const _saveKey = 'active_session';

  /// Classic Pomodoro length, used until the student picks another.
  static const int defaultMinutes = 25;

  /// Length of the current (or next) session, in seconds.
  int durationSeconds = defaultMinutes * 60;

  SessionStatus status = SessionStatus.idle;

  DateTime? _endsAt; // while running
  int _frozenLeft = defaultMinutes * 60; // while paused / after giving up
  Timer? _ticker;

  /// true from the moment a session completes until TimerScreen has
  /// grown the plant and recorded it ([markRecorded]).
  bool _awaitingRecord = false;

  /// true once the current session has been paused at least once.
  bool wasPaused = false;

  /// A long session finished without a single pause (the secret
  /// "deep focus" achievement, see models/secrets.dart).
  bool get wasDeepFocus => durationSeconds >= Secrets.deepFocusMinutes * 60 && !wasPaused;

  /// Seconds left on the clock right now.
  int get secondsLeft {
    switch (status) {
      case SessionStatus.running:
        final ms = _endsAt!.difference(DateTime.now()).inMilliseconds;
        return max(0, (ms / 1000).ceil());
      case SessionStatus.paused:
      case SessionStatus.failed:
        return _frozenLeft;
      case SessionStatus.completed:
        return 0;
      case SessionStatus.idle:
        return durationSeconds;
    }
  }

  /// 0.0 at the start of a session → 1.0 when the timer hits zero.
  double get progress => durationSeconds == 0 ? 0 : 1 - secondsLeft / durationSeconds;

  /// Seconds actually studied so far this session.
  int get elapsedSeconds => durationSeconds - secondsLeft;

  /// A session is in progress (or finished but not recorded yet), so the
  /// Timer should resume it instead of starting a new one.
  bool get isActive =>
      status == SessionStatus.running || status == SessionStatus.paused || (status == SessionStatus.completed && _awaitingRecord);

  String get formattedTime {
    final left = secondsLeft;
    final minutes = (left ~/ 60).toString().padLeft(2, '0');
    final seconds = (left % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Starts a fresh countdown. [minutes] = the length picked on Home;
  /// leave it out to reuse the last length.
  void start({int? minutes}) {
    if (minutes != null && minutes > 0) durationSeconds = minutes * 60;
    _endsAt = DateTime.now().add(Duration(seconds: durationSeconds));
    status = SessionStatus.running;
    _awaitingRecord = false;
    wasPaused = false;
    _runTicker();
    _save();
    notifyListeners();
  }

  void pause() {
    if (status != SessionStatus.running) return;
    _frozenLeft = secondsLeft;
    _endsAt = null;
    _ticker?.cancel();
    status = SessionStatus.paused;
    wasPaused = true;
    _save();
    notifyListeners();
  }

  void resume() {
    if (status != SessionStatus.paused) return;
    _endsAt = DateTime.now().add(Duration(seconds: _frozenLeft));
    status = SessionStatus.running;
    _runTicker();
    _save();
    notifyListeners();
  }

  /// Student taps "Give Up" — session fails, plant should wilt.
  void giveUp() {
    debugPrint('[Session] given up at $formattedTime left.');
    _frozenLeft = secondsLeft; // so elapsedSeconds is still right
    _ticker?.cancel();
    _endsAt = null;
    status = SessionStatus.failed;
    _clearSaved();
    notifyListeners();
  }

  /// TimerScreen calls this once the completed session has been recorded
  /// (plant grown, stats saved), so it can never be counted twice.
  void markRecorded() {
    _awaitingRecord = false;
    _clearSaved();
  }

  /// Reset back to idle so the Home screen shows "Start Study Session" again.
  void reset() {
    debugPrint('[Session] reset from $status.');
    _ticker?.cancel();
    _endsAt = null;
    _awaitingRecord = false;
    status = SessionStatus.idle;
    _clearSaved();
    notifyListeners();
  }

  /// Picks up a session saved before the app was closed. Returns true if
  /// there is one to go back to (running, paused, or finished meanwhile).
  bool restore() {
    final raw = _prefs?.getString(_saveKey);
    debugPrint('[Session] restore: saved = $raw');
    if (raw == null) return false;
    try {
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      durationSeconds = (saved['duration'] as num).toInt();
      wasPaused = saved['pausedOnce'] == true;
      if (saved['status'] == 'running') {
        _endsAt = DateTime.fromMillisecondsSinceEpoch((saved['endsAt'] as num).toInt());
        if (!_endsAt!.isAfter(DateTime.now())) {
          // It finished while the app was closed — it still counts.
          _complete(notify: false);
        } else {
          status = SessionStatus.running;
          _runTicker();
        }
      } else if (saved['status'] == 'paused') {
        _frozenLeft = (saved['left'] as num).toInt();
        status = SessionStatus.paused;
      } else if (saved['status'] == 'completed') {
        _complete(notify: false);
      } else {
        _clearSaved();
        return false;
      }
      notifyListeners();
      return true;
    } catch (error) {
      debugPrint('[Session] could not restore the saved session: $error');
      _clearSaved();
      return false;
    }
  }

  void _complete({bool notify = true}) {
    _ticker?.cancel();
    _endsAt = null;
    status = SessionStatus.completed;
    _awaitingRecord = true;
    _save(); // kept until markRecorded(), in case the app closes mid-growth
    if (notify) notifyListeners();
  }

  void _runTicker() {
    _ticker?.cancel();
    // Ticks only redraw the clock; the time itself comes from _endsAt.
    var shown = -1;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (status != SessionStatus.running) return;
      final left = secondsLeft;
      if (left <= 0) {
        _complete();
      } else if (left != shown) {
        shown = left; // redraw only when the displayed second changes
        notifyListeners();
      }
    });
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    final data = <String, Object>{'duration': durationSeconds, 'status': status.name, 'pausedOnce': wasPaused};
    if (status == SessionStatus.running) data['endsAt'] = _endsAt!.millisecondsSinceEpoch;
    if (status == SessionStatus.paused) data['left'] = _frozenLeft;
    prefs.setString(_saveKey, jsonEncode(data));
  }

  void _clearSaved() => _prefs?.remove(_saveKey);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
