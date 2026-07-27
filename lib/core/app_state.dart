import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'db/app_database.dart';
import 'models/streak.dart';
import 'models/workout.dart';
import 'reminders_service.dart';

class AppState extends ChangeNotifier {
  final _reminders = RemindersService();

  List<Workout> workouts = [];
  bool loaded = false;
  bool remindersEnabled = false;
  int reminderHour = 19;

  Future<void> load() async {
    workouts = await AppDatabase.instance.allWorkouts();
    remindersEnabled = await _reminders.isEnabled();
    reminderHour = await _reminders.hour();
    loaded = true;
    notifyListeners();
  }

  Future<void> setReminders(bool enabled, int hour) async {
    await _reminders.setEnabled(enabled, hour: hour);
    remindersEnabled = enabled;
    reminderHour = hour;
    notifyListeners();
  }

  Future<void> addWorkout(Workout workout) async {
    await AppDatabase.instance.insertWorkout(workout);
    await load();
  }

  Future<void> replaceAll(List<Workout> imported) async {
    await AppDatabase.instance.importWorkouts(imported);
    await load();
  }

  StreakInfo get streak => computeStreak(workouts.map((w) => w.day).toList(), DateTime.now());

  Set<DateTime> get activeDays => workouts.map((w) => w.day).toSet();

  int repsOnDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return workouts.where((w) => w.day == d).fold(0, (sum, w) => sum + w.totalReps);
  }

  int get repsToday => repsOnDay(DateTime.now());

  int repsSince(DateTime since) {
    return workouts
        .where((w) => !w.startedAt.isBefore(since))
        .fold(0, (sum, w) => sum + w.totalReps);
  }

  int get repsAllTime => workouts.fold(0, (sum, w) => sum + w.totalReps);

  String toSnapshotJson() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);

    return jsonEncode({
      'workouts': workouts
          .map((w) => {
                'id': w.id ?? 0,
                'startedAt': w.startedAt.millisecondsSinceEpoch.toDouble(),
                'endedAt': w.endedAt.millisecondsSinceEpoch.toDouble(),
                'sets': w.sets
                    .map((s) => {
                          'reps': s.reps,
                          'startedAt': s.startedAt.millisecondsSinceEpoch.toDouble(),
                          'endedAt': s.endedAt.millisecondsSinceEpoch.toDouble(),
                          'restBeforeSeconds': s.restBeforeSeconds,
                          'repDurationsMs': s.repDurationsMs,
                        })
                    .toList(),
              })
          .toList(),
      'streak': {
        'current': streak.current,
        'longest': streak.longest,
        'brokenToday': streak.brokenToday,
      },
      'repsToday': repsToday,
      'repsThisWeek': repsSince(weekStart),
      'repsThisMonth': repsSince(monthStart),
      'repsAllTime': repsAllTime,
      'activeDayTimestamps':
          activeDays.map((d) => d.millisecondsSinceEpoch.toDouble()).toList(),
      'remindersEnabled': remindersEnabled,
      'reminderHour': reminderHour,
    });
  }
}
