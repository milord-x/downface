import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class RemindersService {
  static const _prefKey = 'reminders_enabled';
  static const _hourKey = 'reminders_hour';
  static const _askedKey = 'reminders_asked';
  static const _notificationId = 42;

  static const _messages = [
    ('One set is all it takes', 'Keep today from breaking your streak.'),
    ('Still time today', 'A quick set now beats none at all.'),
    ('Your streak is waiting', 'Don\'t let today be the day it ends.'),
    ('Face down, streak up', 'One set, and today counts.'),
    ('Quick reminder', 'You haven\'t logged a set today yet.'),
    ('Two minutes is enough', 'Get one set in before the day ends.'),
    ('Don\'t skip today', 'Your streak only grows if you show up.'),
    ('Push-up o\'clock', 'A short session keeps momentum going.'),
    ('Keep the chain going', 'One more day, one more set.'),
    ('Small effort, real progress', 'Today\'s set is still open.'),
    ('Streak check', 'No workout logged yet today.'),
    ('Consistency beats intensity', 'Just one set today.'),
    ('Almost missed it', 'There\'s still time for today\'s set.'),
    ('Show up for yourself', 'One set. That\'s the whole ask.'),
    ('Your future self says thanks', 'Log a set before today ends.'),
  ];

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      iOS: DarwinInitializationSettings(),
    ));
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<int> hour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hourKey) ?? 19;
  }

  Future<bool> hasBeenAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_askedKey) ?? false;
  }

  Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, true);
  }

  Future<void> setEnabled(bool enabled, {int hour = 19}) async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    await prefs.setInt(_hourKey, hour);
    await prefs.setBool(_askedKey, true);

    if (!enabled) {
      await _plugin.cancel(_notificationId);
      return;
    }

    final granted = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (granted == false) return;

    await _scheduleNext(hour);
  }

  Future<void> _scheduleNext(int hour) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final (title, body) = _messages[Random().nextInt(_messages.length)];

    await _plugin.zonedSchedule(
      _notificationId,
      title,
      body,
      scheduled,
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> rescheduleIfEnabled() async {
    if (!await isEnabled()) return;
    await _ensureInit();
    await _scheduleNext(await hour());
  }
}
