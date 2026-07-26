import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class RemindersService {
  static const _prefKey = 'reminders_enabled';
  static const _hourKey = 'reminders_hour';
  static const _notificationId = 42;

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

  Future<void> setEnabled(bool enabled, {int hour = 19}) async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    await prefs.setInt(_hourKey, hour);

    if (!enabled) {
      await _plugin.cancel(_notificationId);
      return;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notificationId,
      'Keep your streak alive',
      'One push-up set is all it takes today.',
      scheduled,
      const NotificationDetails(iOS: DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
