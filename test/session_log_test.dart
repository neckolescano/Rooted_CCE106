import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/session_log.dart';

void main() {
  // Wednesday, 30 Sep 2026, 20:00.
  final now = DateTime(2026, 9, 30, 20);

  SessionLogEntry done(DateTime at, int minutes) => SessionLogEntry(completed: true, seconds: minutes * 60, endedAt: at);
  SessionLogEntry quit(DateTime at, int minutes) => SessionLogEntry(completed: false, seconds: minutes * 60, endedAt: at);

  test('the week starts on Monday at midnight', () {
    expect(startOfWeek(now), DateTime(2026, 9, 28));
    expect(startOfWeek(DateTime(2026, 9, 28, 0, 5)), DateTime(2026, 9, 28));
    expect(startOfWeek(DateTime(2026, 10, 4, 23)), DateTime(2026, 9, 28)); // Sunday
  });

  test('week summary counts only this week, focus time only from finished sessions', () {
    final summary = summarizeWeek([
      done(DateTime(2026, 9, 30, 9), 25),
      quit(DateTime(2026, 9, 29, 18), 7), // gave up: not focus time
      done(DateTime(2026, 9, 28, 8), 50),
      done(DateTime(2026, 9, 27, 22), 25), // last Sunday: not this week
    ], now);
    expect(summary.focusMinutes, 75);
    expect(summary.finished, 2);
    expect(summary.gaveUp, 1);
  });

  test('sessions are grouped by day, newest first', () {
    final groups = groupByDay([
      done(DateTime(2026, 9, 29, 10), 25),
      done(DateTime(2026, 9, 30, 9), 25),
      quit(DateTime(2026, 9, 30, 19), 3),
    ]);
    expect(groups.map((g) => g.$1), [DateTime(2026, 9, 30), DateTime(2026, 9, 29)]);
    expect(groups.first.$2.first.completed, isFalse, reason: 'the 19:00 give-up is the newest');
    expect(groups.first.$2, hasLength(2));
  });

  test('minutes are rounded from seconds', () {
    expect(SessionLogEntry(completed: true, seconds: 89, endedAt: now).minutes, 1);
    expect(SessionLogEntry(completed: true, seconds: 1500, endedAt: now).minutes, 25);
  });
}
