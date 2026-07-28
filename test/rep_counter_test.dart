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

  test('keeps counting past a shallow top-of-rep instead of stalling', () {
    // A rep that only recovers to 0.28 instead of the usual 0.30 (the
    // fatigued user not fully extending their arms) used to permanently
    // shrink the baseline to 0.28, so every following full-depth rep never
    // regenerated enough amplitude to cross downThreshold again.
    final counter = RepCounter(minRepMs: 0);
    var t = 0;
    void sample(double d) {
      counter.onDistanceSample(d, t);
      t += 200;
    }

    for (var i = 0; i < 6; i++) {
      sample(0.30);
      sample(0.15);
      sample(0.30);
    }
    sample(0.28); // shallow recovery
    sample(0.15);
    sample(0.28);
    for (var i = 0; i < 3; i++) {
      sample(0.30);
      sample(0.15);
      sample(0.30);
    }

    expect(counter.reps, 10);
  });

  test('flags fatigue once several reps in a row slow well past the set pace', () {
    final counter = RepCounter(
      minRepMs: 0,
      fatigueRepThreshold: 2,
      fatigueWindow: 2,
      fatigueSlowdownRatio: 1.4,
    );
    RepEvent? last;
    var t = 0;
    void sample(double d) {
      last = counter.onDistanceSample(d, t) ?? last;
      t += 100;
    }
    void fastRep() {
      sample(0.30);
      sample(0.15);
      sample(0.30);
    }
    void slowRep() {
      // Same amplitude, much slower cycle: linger at the bottom for several
      // extra samples before recovering, instead of going straight back up.
      sample(0.30);
      for (var i = 0; i < 5; i++) {
        sample(0.15);
      }
      sample(0.30);
    }

    fastRep();
    fastRep();
    expect(last?.fatigued, false);

    slowRep();
    expect(last?.fatigued, false, reason: 'one slow rep alone should not trip fatigue');

    slowRep();
    expect(last?.fatigued, true, reason: 'two slow reps in a row should trip fatigue');
  });

  test('a single noisy slow rep does not trigger fatigue on its own', () {
    final counter = RepCounter(
      minRepMs: 0,
      fatigueRepThreshold: 2,
      fatigueWindow: 3,
      fatigueSlowdownRatio: 1.4,
    );
    RepEvent? last;
    var t = 0;
    void sample(double d) {
      last = counter.onDistanceSample(d, t) ?? last;
      t += 100;
    }

    sample(0.30);
    sample(0.15);
    sample(0.30);
    sample(0.30);
    sample(0.15);
    sample(0.30);

    // One rep with a brief pause (e.g. adjusting position), then straight
    // back to the normal pace — diluted by the other fast reps in the
    // rolling window, so it shouldn't trip fatigue on its own.
    sample(0.30);
    for (var i = 0; i < 5; i++) {
      sample(0.15);
    }
    sample(0.30);
    expect(last?.fatigued, false);

    sample(0.30);
    sample(0.15);
    sample(0.30);
    expect(last?.fatigued, false);
  });

  test('fatigue stays flagged for the rest of the set once triggered', () {
    final counter = RepCounter(
      minRepMs: 0,
      fatigueRepThreshold: 2,
      fatigueWindow: 2,
      fatigueSlowdownRatio: 1.4,
    );
    RepEvent? last;
    var t = 0;
    void sample(double d) {
      last = counter.onDistanceSample(d, t) ?? last;
      t += 100;
    }
    void slowRep() {
      sample(0.30);
      for (var i = 0; i < 5; i++) {
        sample(0.15);
      }
      sample(0.30);
    }

    sample(0.30);
    sample(0.15);
    sample(0.30);
    sample(0.30);
    sample(0.15);
    sample(0.30);
    slowRep();
    slowRep();
    expect(last?.fatigued, true);

    // Back to a fast rep — a real tired set doesn't suddenly stop being
    // tired because one rep happened to land quicker.
    sample(0.30);
    sample(0.15);
    sample(0.30);
    expect(last?.fatigued, true);
  });
}
