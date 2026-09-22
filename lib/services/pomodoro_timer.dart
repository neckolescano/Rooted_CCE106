import 'dart:async';

/// The lifecycle a single Pomodoro session moves through.
enum SessionStatus { idle, running, paused, completed, failed }

/// A Pomodoro countdown timer.
///
/// Deliberately avoids a simple "subtract one second every tick"
/// counter, because that drifts if the app is backgrounded and ticks
/// get delayed or skipped. Instead, every tick recomputes the time
/// remaining from a fixed end-time (`DateTime.now()`), so the
/// countdown stays accurate regardless of how the OS schedules the
/// timer while the app is backgrounded.
class PomodoroTimer {
  final Duration sessionDuration;
  final void Function(Duration remaining) onTick;
  final void Function() onComplete;
  final void Function() onFail;

  SessionStatus status = SessionStatus.idle;

  Timer? _ticker;
  DateTime? _endTime;
  Duration _remaining;

  PomodoroTimer({
    required this.sessionDuration,
    required this.onTick,
    required this.onComplete,
    required this.onFail,
  }) : _remaining = sessionDuration;

  Duration get remaining => _remaining;

  void start() {
    if (status == SessionStatus.running) return;
    status = SessionStatus.running;
    _endTime = DateTime.now().add(_remaining);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (status != SessionStatus.running) return;
    _ticker?.cancel();
    _remaining = _timeLeft();
    status = SessionStatus.paused;
  }

  void resume() => start();

  /// Student gives up or the session is otherwise abandoned before
  /// finishing. Triggers the plant's wilt state.
  void giveUp() {
    _ticker?.cancel();
    status = SessionStatus.failed;
    onFail();
  }

  /// Resets to a fresh, un-started session of the same duration.
  void reset() {
    _ticker?.cancel();
    _remaining = sessionDuration;
    status = SessionStatus.idle;
    onTick(_remaining);
  }

  void dispose() {
    _ticker?.cancel();
  }

  Duration _timeLeft() {
    if (_endTime == null) return _remaining;
    final left = _endTime!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    final left = _timeLeft();
    if (left == Duration.zero) {
      _ticker?.cancel();
      status = SessionStatus.completed;
      onTick(Duration.zero);
      onComplete();
    } else {
      _remaining = left;
      onTick(left);
    }
  }
}
