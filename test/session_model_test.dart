import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/models/session_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('start saves the session; give up clears it', () async {
    final prefs = await prefsWith();
    final session = SessionModel(prefs: prefs)..start(minutes: 25);
    expect(session.isActive, isTrue);
    expect(session.secondsLeft, inInclusiveRange(1499, 1500));
    expect(prefs.getString('active_session'), isNotNull);

    session.giveUp();
    expect(session.status, SessionStatus.failed);
    expect(prefs.getString('active_session'), isNull);
    session.dispose();
  });

  test('a running session is restored with the right time left', () async {
    final endsAt = DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;
    final prefs = await prefsWith({
      'active_session': jsonEncode({'duration': 1500, 'status': 'running', 'endsAt': endsAt}),
    });
    final session = SessionModel(prefs: prefs);
    expect(session.restore(), isTrue);
    expect(session.status, SessionStatus.running);
    expect(session.secondsLeft, inInclusiveRange(599, 600));
    session.dispose();
  });

  test('a session that ended while the app was closed still counts, once', () async {
    final endsAt = DateTime.now().subtract(const Duration(minutes: 3)).millisecondsSinceEpoch;
    final prefs = await prefsWith({
      'active_session': jsonEncode({'duration': 1500, 'status': 'running', 'endsAt': endsAt}),
    });
    final session = SessionModel(prefs: prefs);
    expect(session.restore(), isTrue);
    expect(session.status, SessionStatus.completed);
    expect(session.isActive, isTrue, reason: 'the Timer should reopen and record it');

    session.markRecorded();
    expect(session.isActive, isFalse, reason: 'recorded → never counted again');
    expect(prefs.getString('active_session'), isNull);
    session.dispose();
  });

  test('pause keeps the time left, also across a restart', () async {
    final prefs = await prefsWith();
    final session = SessionModel(prefs: prefs)..start(minutes: 25);
    session.pause();
    final left = session.secondsLeft;

    final reopened = SessionModel(prefs: prefs);
    expect(reopened.restore(), isTrue);
    expect(reopened.status, SessionStatus.paused);
    expect(reopened.secondsLeft, left);
    session.dispose();
    reopened.dispose();
  });

  test('a corrupt save is dropped instead of crashing', () async {
    final prefs = await prefsWith({'active_session': '{not json'});
    final session = SessionModel(prefs: prefs);
    expect(session.restore(), isFalse);
    expect(session.status, SessionStatus.idle);
    expect(prefs.getString('active_session'), isNull);
  });
}
