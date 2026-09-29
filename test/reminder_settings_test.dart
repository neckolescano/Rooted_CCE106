import 'package:flutter_test/flutter_test.dart';
import 'package:rooted/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reminders are off by default, at 7:00 PM', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    expect(storage.remindersOn, isFalse);
    expect(storage.reminderMinutes, 19 * 60);
  });

  test('turning reminders on and changing the time is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.setReminders(on: true, minutes: 8 * 60 + 30);

    final reopened = await StorageService.create();
    expect(reopened.remindersOn, isTrue);
    expect(reopened.reminderMinutes, 8 * 60 + 30);
  });

  test('finishing a session today skips today\'s reminder', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    expect(storage.studiedToday, isFalse);

    await storage.recordCompletedSession(durationSeconds: 60);
    expect(storage.studiedToday, isTrue);
    expect(storage.completedSessions, 1);
  });

  test('giving up does not count as studying today', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.recordFailedSession(elapsedSeconds: 30);
    expect(storage.studiedToday, isFalse);
  });
}
