/// One study session from the user's log (users/{uid}/sessions in
/// Firestore) — written when a session finishes or is given up.
class SessionLogEntry {
  const SessionLogEntry({required this.completed, required this.seconds, required this.endedAt});

  final bool completed;

  /// The session's length (finished) or how long it ran before giving up.
  final int seconds;

  /// When it ended, in the phone's local time.
  final DateTime endedAt;

  int get minutes => (seconds / 60).round();
}

/// This week's numbers for the top of the Study Log.
class WeekSummary {
  const WeekSummary({required this.focusMinutes, required this.finished, required this.gaveUp});

  final int focusMinutes; // finished sessions only
  final int finished;
  final int gaveUp;
}

/// Monday 00:00 of the week [now] is in.
DateTime startOfWeek(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
}

WeekSummary summarizeWeek(List<SessionLogEntry> entries, DateTime now) {
  final from = startOfWeek(now);
  var minutes = 0, finished = 0, gaveUp = 0;
  for (final e in entries) {
    if (e.endedAt.isBefore(from)) continue;
    if (e.completed) {
      finished++;
      minutes += e.minutes;
    } else {
      gaveUp++;
    }
  }
  return WeekSummary(focusMinutes: minutes, finished: finished, gaveUp: gaveUp);
}

/// Entries grouped by calendar day, newest day first (entries keep their
/// order inside a day, newest first).
List<(DateTime day, List<SessionLogEntry> entries)> groupByDay(List<SessionLogEntry> entries) {
  final sorted = [...entries]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
  final groups = <(DateTime, List<SessionLogEntry>)>[];
  for (final e in sorted) {
    final day = DateTime(e.endedAt.year, e.endedAt.month, e.endedAt.day);
    if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
    groups.last.$2.add(e);
  }
  return groups;
}
