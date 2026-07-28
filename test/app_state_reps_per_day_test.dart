import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:downface/core/app_state.dart';
import 'package:downface/core/models/workout.dart';
import 'package:downface/core/models/workout_set.dart';

Workout _workout(DateTime startedAt, int reps) {
  return Workout(
    id: null,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 5)),
    sets: [
      WorkoutSet(
        id: null,
        workoutId: 0,
        reps: reps,
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 5)),
        restBeforeSeconds: 0,
        repDurationsMs: const [],
      ),
    ],
  );
}

void main() {
  test('repsPerDay aggregates reps by local calendar day, independent of time of day', () {
    final appState = AppState();
    appState.workouts = [
      _workout(DateTime(2026, 7, 27, 8, 0), 10),
      _workout(DateTime(2026, 7, 27, 23, 30), 5),
      _workout(DateTime(2026, 7, 26, 12, 0), 8),
    ];

    final perDay = appState.repsPerDay;

    expect(perDay[DateTime(2026, 7, 27)], 15);
    expect(perDay[DateTime(2026, 7, 26)], 8);
    expect(perDay.length, 2);
  });

  test('repsPerDay is empty when there are no workouts', () {
    final appState = AppState();
    expect(appState.repsPerDay, isEmpty);
  });

  test('toSnapshotJson serializes repsPerDay with yyyy-MM-dd string keys, not raw timestamps', () {
    final appState = AppState();
    appState.workouts = [
      _workout(DateTime(2026, 7, 27, 8, 0), 20),
      _workout(DateTime(2026, 3, 5, 9, 0), 5),
    ];

    final decoded = jsonDecode(appState.toSnapshotJson()) as Map<String, dynamic>;
    final repsPerDay = decoded['repsPerDay'] as Map<String, dynamic>;

    expect(repsPerDay['2026-07-27'], 20);
    expect(repsPerDay['2026-03-05'], 5);
  });
}
