import 'dart:async';
import 'package:flutter/material.dart';

enum SessionStatus { idle, running, paused, completed, failed }

/// Runs the 25-minute Pomodoro countdown and reports back whether the
/// session finished successfully or was given up on. TimerScreen listens
/// to this to update the clock, and reacts to completed/failed to
/// grow or wilt the plant.
class SessionModel extends ChangeNotifier {
  static const int sessionLengthSeconds = 25 * 60; // 25:00, matches the Figma

  int secondsLeft = sessionLengthSeconds;
  SessionStatus status = SessionStatus.idle;
  Timer? _timer;

  String get formattedTime {
    final minutes = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void start() {
    secondsLeft = sessionLengthSeconds;
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
    secondsLeft = sessionLengthSeconds;
    status = SessionStatus.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
