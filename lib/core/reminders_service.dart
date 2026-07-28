import 'dart:convert';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_messages.dart';

class RemindersService {
  static const _prefKey = 'reminders_enabled';
  static const _minutesKey = 'reminders_minutes';
  static const _legacyHoursKey = 'reminders_hours';
  static const _askedKey = 'reminders_asked';
  static const _baseNotificationId = 42;
  static const _streakRiskNotificationId = 999;

  /// The Settings screen caps "Add another time" at this many configured
  /// reminders — kept in sync here so cancellation covers every ID that
  /// could ever have been scheduled.
  static const maxReminderTimes = 4;

  /// The app's own locale picker doesn't exist — this mirrors whatever
  /// language iOS itself is set to, same source Localizable.xcstrings uses.
  /// Chinese needs the script subtag (zh-Hans, not just "zh") to match the
  /// message table's keys, which follow Localizable.xcstrings' naming.
  static String get _languageCode {
    final locale = PlatformDispatcher.instance.locale;
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ? 'zh-Hant' : 'zh-Hans';
    }
    return locale.languageCode;
  }

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // tz.local defaults to UTC until a location is explicitly set — without
    // this, every zonedSchedule call below silently plans notifications
    // against UTC instead of the device's real timezone, so a reminder set
    // for e.g. 19:00 fires at 19:00 UTC instead and never seems to arrive
    // at the expected local time.
    final deviceTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));
    await _plugin.initialize(const InitializationSettings(
      iOS: DarwinInitializationSettings(),
    ));
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Each value is minutes since midnight (0-1439), in 5-minute steps.
  Future<List<int>> minutesOfDay() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_minutesKey);
    if (raw != null) {
      return (jsonDecode(raw) as List<dynamic>).cast<int>();
    }

    final legacyRaw = prefs.getString(_legacyHoursKey);
    if (legacyRaw != null) {
      final hours = (jsonDecode(legacyRaw) as List<dynamic>).cast<int>();
      final minutes = hours.map((h) => h * 60).toList();
      await prefs.setString(_minutesKey, jsonEncode(minutes));
      await prefs.remove(_legacyHoursKey);
      return minutes;
    }

    final now = DateTime.now();
    return [now.hour * 60 + now.minute];
  }

  Future<bool> hasBeenAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_askedKey) ?? false;
  }

  Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, true);
  }

  /// Returns whether reminders actually ended up enabled — false if the
  /// user asked to enable them but denied (or had already denied) the
  /// system notification permission, so the caller can reflect that back
  /// in the UI instead of showing an "on" toggle that silently never fires.
  Future<bool> setEnabled(bool enabled, {List<int>? minutesOfDay}) async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    if (minutesOfDay != null) {
      await prefs.setString(_minutesKey, jsonEncode(minutesOfDay));
    }
    await prefs.setBool(_askedKey, true);

    if (!enabled) {
      await prefs.setBool(_prefKey, false);
      await _cancelAll();
      return false;
    }

    final granted = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (granted == false) {
      await prefs.setBool(_prefKey, false);
      return false;
    }

    await prefs.setBool(_prefKey, true);
    await _scheduleAll(minutesOfDay: minutesOfDay ?? await this.minutesOfDay(), streakAtRisk: false);
    return true;
  }

  Future<void> _cancelAll() async {
    // Wider than maxReminderTimes so a device that saved more times under
    // an older version (before the 4-time cap) still gets every pending
    // notification cleared, not just the first 4 slots.
    for (var i = 0; i < 12; i++) {
      await _plugin.cancel(_baseNotificationId + i);
    }
    await _plugin.cancel(_streakRiskNotificationId);
  }

  Future<void> _scheduleAll({required List<int> minutesOfDay, required bool streakAtRisk}) async {
    await _cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    final pool = messagesFor(streakAtRisk ? urgentReminderMessages : dailyReminderMessages, _languageCode);

    for (var i = 0; i < minutesOfDay.length; i++) {
      final hour = minutesOfDay[i] ~/ 60;
      final minute = minutesOfDay[i] % 60;
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      final (title, body) = pool[Random().nextInt(pool.length)];
      await _plugin.zonedSchedule(
        _baseNotificationId + i,
        title,
        body,
        scheduled,
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    if (streakAtRisk) {
      await _scheduleStreakLossWarning(now: now);
    }
  }

  /// Schedules the one-off "you'll lose your streak" notification for
  /// 23:00 local time today, independent of the user's configured reminder
  /// times. Only called when a streak is actually at risk — see
  /// [rescheduleIfEnabled].
  Future<void> _scheduleStreakLossWarning({required tz.TZDateTime now}) async {
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 23, 0);
    if (scheduled.isBefore(now)) return;
    final pool = messagesFor(streakLossReminderMessages, _languageCode);
    final (title, body) = pool[Random().nextInt(pool.length)];
    await _plugin.zonedSchedule(
      _streakRiskNotificationId,
      title,
      body,
      scheduled,
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Reschedules pending reminders. If [doneToday] is true, today's
  /// reminders are skipped and only tomorrow's are queued. If
  /// [streakAtRisk] is true (no workout yet and streak would break today),
  /// the remaining reminders for today use more urgent copy.
  Future<void> rescheduleIfEnabled({required bool doneToday, required bool streakAtRisk}) async {
    if (!await isEnabled()) return;
    await _ensureInit();
    final configured = await minutesOfDay();
    if (doneToday) {
      await _cancelAll();
      final now = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < configured.length; i++) {
        final hour = configured[i] ~/ 60;
        final minute = configured[i] % 60;
        final scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
            .add(const Duration(days: 1));
        final pool = messagesFor(dailyReminderMessages, _languageCode);
        final (title, body) = pool[Random().nextInt(pool.length)];
        await _plugin.zonedSchedule(
          _baseNotificationId + i,
          title,
          body,
          scheduled,
          const NotificationDetails(iOS: DarwinNotificationDetails()),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
      return;
    }
    await _scheduleAll(minutesOfDay: configured, streakAtRisk: streakAtRisk);
  }
}
