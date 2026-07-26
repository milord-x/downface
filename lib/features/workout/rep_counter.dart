enum RepPhase { up, down }

class RepEvent {
  const RepEvent({required this.reps, required this.durationMs});
  final int reps;
  final int durationMs;
}

class RepCounter {
  RepCounter({
    this.downThreshold = 0.035,
    this.upThreshold = 0.015,
    this.minRepMs = 400,
  });

  final double downThreshold;
  final double upThreshold;
  final int minRepMs;

  double? _baseline;
  RepPhase _phase = RepPhase.up;
  int reps = 0;
  int? _repStartMs;
  int? _lastRepDurationMs;

  int? get lastRepDurationMs => _lastRepDurationMs;

  void reset() {
    _baseline = null;
    _phase = RepPhase.up;
    reps = 0;
    _repStartMs = null;
    _lastRepDurationMs = null;
  }

  /// [distance] is the face-to-camera distance in meters. It shrinks as the
  /// user descends toward the phone and grows back on the way up.
  RepEvent? onDistanceSample(double distance, int timestampMs) {
    _baseline ??= distance;
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
      _baseline = distance;
      return RepEvent(reps: reps, durationMs: durationMs);
    }

    return null;
  }
}
