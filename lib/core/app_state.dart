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
  List<int> reminderMinutes = [19 * 60];
  bool remindersAsked = false;

  bool get _didWorkoutToday => activeDays.contains(DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ));

  bool get _streakAtRisk => !_didWorkoutToday && streak.current > 0;

  Future<void> load() async {
    workouts = await AppDatabase.instance.allWorkouts();
    remindersEnabled = await _reminders.isEnabled();
    reminderMinutes = await _reminders.minutesOfDay();
    remindersAsked = await _reminders.hasBeenAsked();
    await _reminders.rescheduleIfEnabled(doneToday: _didWorkoutToday, streakAtRisk: _streakAtRisk);
    loaded = true;
    notifyListeners();
  }

  Future<void> setReminders(bool enabled, List<int> minutesOfDay) async {
    await _reminders.setEnabled(enabled, minutesOfDay: minutesOfDay);
    remindersEnabled = enabled;
    reminderMinutes = minutesOfDay;
    remindersAsked = true;
    notifyListeners();
  }

  Future<void> declineReminders() async {
    await _reminders.markAsked();
    remindersAsked = true;
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

  Map<DateTime, int> get repsPerDay {
    final totals = <DateTime, int>{};
    for (final w in workouts) {
      totals[w.day] = (totals[w.day] ?? 0) + w.totalReps;
    }
    return totals;
  }

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

  /// yyyy-MM-dd in local time, matching the widget's day-key format —
  /// avoids any floating-point precision mismatch that a millisecond
  /// timestamp key would risk across the Dart/Swift JSON round trip.
  String _dayKey(DateTime day) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

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
      'repsPerDay': repsPerDay.map(
        (day, reps) => MapEntry(_dayKey(day), reps),
      ),
      'remindersEnabled': remindersEnabled,
      'reminderMinutes': reminderMinutes,
      'remindersAsked': remindersAsked,
    });
  }
}
