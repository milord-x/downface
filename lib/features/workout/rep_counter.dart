enum RepPhase { up, down }

class RepEvent {
  const RepEvent({required this.reps, required this.durationMs, required this.fatigued});
  final int reps;
  final int durationMs;
  final bool fatigued;
}

class RepCounter {
  RepCounter({
    this.downThreshold = 0.035,
    this.upThreshold = 0.015,
    this.minRepMs = 400,
    this.fatigueRepThreshold = 4,
    this.fatigueSlowdownRatio = 1.45,
  });

  final double downThreshold;
  final double upThreshold;
  final int minRepMs;

  /// Reps counted before fatigue detection kicks in — the first few reps of
  /// a set set the pace baseline and are too noisy on their own to compare
  /// against.
  final int fatigueRepThreshold;

  /// A rep is flagged as fatigued once its cycle takes this many times
  /// longer than the set's baseline pace (average of its first
  /// [fatigueRepThreshold] reps).
  final double fatigueSlowdownRatio;

  double? _baseline;
  RepPhase _phase = RepPhase.up;
  int reps = 0;
  int? _repStartMs;
  int? _lastRepDurationMs;
  final List<int> repDurationsMs = [];

  int? get lastRepDurationMs => _lastRepDurationMs;

  void reset() {
    _baseline = null;
    _phase = RepPhase.up;
    reps = 0;
    _repStartMs = null;
    _lastRepDurationMs = null;
    repDurationsMs.clear();
  }

  /// [distance] is the face-to-camera distance in meters. It shrinks as the
  /// user descends toward the phone and grows back on the way up.
  RepEvent? onDistanceSample(double distance, int timestampMs) {
    _baseline ??= distance;

    // Track the highest point (largest distance) seen since the last rep
    // instead of snapping the baseline to whatever sample happens to land
    // when the phase flips back to up. Snapping meant a single rep where
    // the user didn't fully extend their arms — normal once fatigue sets
    // in — permanently shrank the baseline, so every following rep had less
    // and less amplitude to work with until none could cross downThreshold
    // again and counting silently stalled a few reps in.
    if (_phase == RepPhase.up && distance > _baseline!) {
      _baseline = distance;
    }

    final delta = _baseline! - distance;

    if (_phase == RepPhase.up && delta > downThreshold) {
      _phase = RepPhase.down;
      _repStartMs ??= timestampMs;
      return null;
    }

    if (_phase == RepPhase.down && delta < upThreshold) {
      _phase = RepPhase.up;
      final start = _repStartMs;
      _repStartMs = null;
      if (start == null) return null;
      final durationMs = timestampMs - start;
      if (durationMs < minRepMs) return null;
      reps++;
      _lastRepDurationMs = durationMs;
      repDurationsMs.add(durationMs);
      return RepEvent(reps: reps, durationMs: durationMs, fatigued: _isFatigued(durationMs));
    }

    return null;
  }

  bool _isFatigued(int durationMs) {
    if (reps <= fatigueRepThreshold) return false;
    final baseline = repDurationsMs.take(fatigueRepThreshold);
    final baselineAvg = baseline.reduce((a, b) => a + b) / baseline.length;
    return durationMs > baselineAvg * fatigueSlowdownRatio;
  }
}
