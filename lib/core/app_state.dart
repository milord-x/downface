import 'package:flutter/foundation.dart';

import 'db/app_database.dart';
import 'models/streak.dart';
import 'models/workout.dart';

class AppState extends ChangeNotifier {
  List<Workout> workouts = [];
  bool loaded = false;

  Future<void> load() async {
    workouts = await AppDatabase.instance.allWorkouts();
    loaded = true;
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
}
