// Generates a realistic month of workout history and encrypts it through
// the app's own BackupCodec, so it imports via the normal "Import backup
// file" flow for testing.
//
// Run: dart run tool/generate_test_backup.dart
import 'dart:io';
import 'dart:math';

import 'package:downface/core/export/backup_codec.dart';
import 'package:downface/core/models/workout.dart';
import 'package:downface/core/models/workout_set.dart';

Future<void> main() async {
  final random = Random(7);
  final today = DateTime.now();
  final startDay = today.subtract(const Duration(days: 29));

  final workouts = <Workout>[];
  var streakRepBias = 8;

  for (var offset = 0; offset < 30; offset++) {
    final day = DateTime(startDay.year, startDay.month, startDay.day + offset);

    // Roughly a real routine: skip Sundays, plus a handful of random misses.
    final isSunday = day.weekday == DateTime.sunday;
    final randomMiss = random.nextDouble() < 0.12;
    if (isSunday || randomMiss) continue;

    // Workout time drifts around evening, occasional morning session.
    final hour = random.nextDouble() < 0.2 ? 7 + random.nextInt(2) : 18 + random.nextInt(3);
    final minute = random.nextInt(60);
    var cursor = DateTime(day.year, day.month, day.day, hour, minute);
    final workoutStart = cursor;

    // Baseline strength slowly rises over the month, with day-to-day noise.
    final progress = offset / 29;
    streakRepBias = (8 + (progress * 7).round() + random.nextInt(3) - 1).clamp(6, 20);

    final setCount = 2 + random.nextInt(3);
    final sets = <WorkoutSet>[];
    var restBefore = 0;

    for (var setIndex = 0; setIndex < setCount; setIndex++) {
      if (setIndex > 0) {
        restBefore = 40 + random.nextInt(80);
        cursor = cursor.add(Duration(seconds: restBefore));
      }

      final repsInSet = max(3, streakRepBias - setIndex * 2 + random.nextInt(3) - 1);
      final repDurations = <int>[];
      var setCursor = cursor;
      for (var rep = 0; rep < repsInSet; rep++) {
        // Reps slow down slightly toward the end of a set (fatigue).
        final base = 900 + random.nextInt(300);
        final fatigueSlowdown = (rep / repsInSet * 400).round();
        final durationMs = base + fatigueSlowdown;
        repDurations.add(durationMs);
        setCursor = setCursor.add(Duration(milliseconds: durationMs));
      }

      sets.add(WorkoutSet(
        id: null,
        workoutId: 0,
        reps: repsInSet,
        startedAt: cursor,
        endedAt: setCursor,
        restBeforeSeconds: restBefore,
        repDurationsMs: repDurations,
      ));

      cursor = setCursor;
    }

    workouts.add(Workout(id: null, startedAt: workoutStart, endedAt: cursor, sets: sets));
  }

  final bytes = await BackupCodec.encode(workouts);
  final outFile = File('test_backup_30_days.downfacebak');
  await outFile.writeAsBytes(bytes);

  final totalReps = workouts.fold<int>(0, (sum, w) => sum + w.totalReps);
  stdout.writeln('Wrote ${outFile.path}');
  stdout.writeln('${workouts.length} workouts, $totalReps total reps over 30 days');
}
