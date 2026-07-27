import 'package:flutter_test/flutter_test.dart';
import 'package:downface/features/workout/rep_counter.dart';

void main() {
  test('counts one full down-up cycle as a rep', () {
    final counter = RepCounter(minRepMs: 0);
    RepEvent? last;
    var t = 0;
    for (final d in [0.30, 0.30, 0.20, 0.15, 0.15, 0.20, 0.30, 0.30]) {
      last = counter.onDistanceSample(d, t) ?? last;
      t += 100;
    }
    expect(counter.reps, 1);
    expect(last?.reps, 1);
  });

  test('ignores tiny jitter under threshold', () {
    final counter = RepCounter(minRepMs: 0);
    var t = 0;
    for (final d in [0.30, 0.295, 0.30, 0.298, 0.30]) {
      counter.onDistanceSample(d, t);
      t += 100;
    }
    expect(counter.reps, 0);
  });

  test('rejects reps faster than minRepMs', () {
    final counter = RepCounter(minRepMs: 500);
    var t = 0;
    for (final d in [0.30, 0.15, 0.30]) {
      counter.onDistanceSample(d, t);
      t += 50;
    }
    expect(counter.reps, 0);
  });

  test('counts multiple consecutive reps', () {
    final counter = RepCounter(minRepMs: 0);
    var t = 0;
    for (var i = 0; i < 3; i++) {
      for (final d in [0.30, 0.15, 0.30]) {
        counter.onDistanceSample(d, t);
        t += 200;
      }
    }
    expect(counter.reps, 3);
  });
}
