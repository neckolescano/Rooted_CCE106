import 'dart:async';
import 'package:flutter/material.dart';

enum SessionStatus { idle, running, paused, completed, failed }

/// Runs the Pomodoro countdown and reports back whether the session
/// finished successfully or was given up on. TimerScreen listens to this
/// to update the clock, and reacts to completed/failed to grow or wilt
/// the plant.
///
/// The length is chosen on the Home screen (the FOCUS TIME setter) and
/// passed to [start].
class SessionModel extends ChangeNotifier {
  /// Classic Pomodoro length, used until the student picks another.
  static const int defaultMinutes = 25;

  /// Length of the current (or next) session, in seconds.
  int durationSeconds = defaultMinutes * 60;

  int secondsLeft = defaultMinutes * 60;
  SessionStatus status = SessionStatus.idle;
  Timer? _timer;

  /// 0.0 at the start of a session → 1.0 when the timer hits zero.
  double get progress => durationSeconds == 0 ? 0 : 1 - secondsLeft / durationSeconds;

  /// Seconds actually studied so far this session.
  int get elapsedSeconds => durationSeconds - secondsLeft;

  String get formattedTime {
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Starts a fresh countdown. [minutes] = the length picked on Home;
  /// leave it out to reuse the last length.
  void start({int? minutes}) {
    if (minutes != null && minutes > 0) durationSeconds = minutes * 60;
    secondsLeft = durationSeconds;
    status = SessionStatus.running;
    _runTimer();
    notifyListeners();
  }

  void pause() {
    if (status != SessionStatus.running) return;
    _timer?.cancel();
    status = SessionStatus.paused;
    notifyListeners();
  }

  void resume() {
    if (status != SessionStatus.paused) return;
    status = SessionStatus.running;
    _runTimer();
    notifyListeners();
  }

  /// Student taps "Give Up" — session fails, plant should wilt.
  void giveUp() {
    _timer?.cancel();
    status = SessionStatus.failed;
    notifyListeners();
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft <= 1) {
        secondsLeft = 0;
        status = SessionStatus.completed;
        timer.cancel();
      } else {
        secondsLeft--;
      }
      notifyListeners();
    });
  }

  /// Reset back to idle so the Home screen shows "Start Study Session" again.
  void reset() {
    _timer?.cancel();
    secondsLeft = durationSeconds;
    status = SessionStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
