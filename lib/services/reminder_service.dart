import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'storage_service.dart';

/// The daily study reminder: a notification from kuwago at the time the
/// student picks on the Profile screen ("Push Reminders").
///
/// It only nudges on days without a finished session: finishing one moves
/// the next reminder to tomorrow. The phone itself shows it at that time
/// (even when the app is closed), and puts it back after a restart
/// (see the receivers in AndroidManifest.xml).
class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _ready;
  static const _id = 7; // the one reminder

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'study_reminders',
      'Study reminders',
      channelDescription: 'A daily nudge from kuwago to do a focus session',
      icon: 'ic_stat_kuwago', // white owl silhouette (tool/generate_icon.dart)
      color: Color(0xFF7CB350),
    ),
  );

  /// Sets up the plugin and the phone's time zone, once.
  static Future<void> _init() => _ready ??= _setUp();

  static Future<void> _setUp() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      // Rare: unknown zone name. Use any zone with the phone's current
      // UTC offset, so the reminder still comes at the right hour.
      debugPrint('[Reminders] time zone not found ($error) — matching the UTC offset');
      final offset = DateTime.now().timeZoneOffset;
      final match = tz.timeZoneDatabase.locations.values
          .where((l) => l.currentTimeZone.offset == offset)
          .firstOrNull;
      if (match != null) tz.setLocalLocation(match);
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_kuwago')),
    );
  }

  /// Asks for permission to show notifications (Android 13+ shows a
  /// dialog; older Androids allow it already). Returns whether it's allowed.
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Makes the scheduled reminder match the saved settings: scheduled at
  /// the chosen time (starting tomorrow if the student already studied
  /// today), or cancelled when reminders are off. Safe to call often.
  static Future<void> apply(StorageService storage, {required String plantName}) async {
    if (kIsWeb) return;
    try {
      await _init();
      await _plugin.cancel(id: _id);
      if (!storage.remindersOn) return;

      final minutes = storage.reminderMinutes;
      final now = tz.TZDateTime.now(tz.local);
      var first = tz.TZDateTime(tz.local, now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
      if (!first.isAfter(now) || storage.studiedToday) {
        first = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, minutes ~/ 60, minutes % 60);
      }
      final message = _messages(plantName)[Random().nextInt(3)];
      await _plugin.zonedSchedule(
        id: _id,
        scheduledDate: first,
        notificationDetails: _details,
        // Inexact = no special "exact alarm" permission needed; Android may
        // shift it by a few minutes to save battery, which is fine here.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: message.$1,
        body: message.$2,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
      debugPrint('[Reminders] next reminder: $first');
    } catch (error) {
      debugPrint('[Reminders] could not schedule: $error');
    }
  }

  /// Removes the reminder (e.g. when signing out).
  static Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      await _init();
      await _plugin.cancel(id: _id);
    } catch (error) {
      debugPrint('[Reminders] could not cancel: $error');
    }
  }

  static List<(String, String)> _messages(String plant) => [
        ('Hoo! kuwago here 🦉', 'Your $plant is waiting — a short focus session keeps it growing 🌱'),
        ('Time to grow 🌱', 'One focus session today and your $plant gets a little taller.'),
        ('Your garden misses you 🦉', "Hoo… your $plant could use some focus light today."),
      ];
}
