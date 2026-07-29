enum RepPhase { up, down }

class RepEvent {
  const RepEvent({required this.reps, required this.durationMs, required this.fatigued});
  final int reps;
  final int durationMs;
  final bool fatigued;
}

class RepCounter {
  RepCounter({
    this.downThreshold = 0.02,
    this.upThreshold = 0.01,
    this.minRepMs = 400,
    this.fatigueRepThreshold = 4,
    this.fatigueSlowdownRatio = 1.35,
    this.fatigueWindow = 3,
    this.calibrationRepCount = 3,
  });

  double downThreshold;
  double upThreshold;
  final int minRepMs;

  /// How many reps of a session are used to measure the user's actual
  /// range of motion before the threshold adapts to it. A fixed threshold
  /// works for a full-depth push-up with the phone flat on the floor, but
  /// an angled phone or a shorter range of motion needs a smaller one — and
  /// a threshold set for someone with a huge range of motion is needlessly
  /// strict for someone with a smaller one, and vice versa.
  final int calibrationRepCount;
  final List<double> _repAmplitudes = [];
  bool _calibrated = false;

  /// Restores thresholds learned in a previous session, marking calibration
  /// already done so this session doesn't re-measure and potentially
  /// overwrite a good threshold with a noisier one from just a few reps.
  void applyPersistedCalibration(double downThreshold, double upThreshold) {
    this.downThreshold = downThreshold;
    this.upThreshold = upThreshold;
    _calibrated = true;
  }

  /// Called once, right when calibration completes for the first time this
  /// session, so the caller can persist the newly learned thresholds.
  void Function(double downThreshold, double upThreshold)? onCalibrated;

  /// Reps counted before fatigue detection kicks in — the first few reps of
  /// a set set the pace baseline and are too noisy on their own to compare
  /// against.
  final int fatigueRepThreshold;

  /// Fatigue triggers once the rolling average of the last [fatigueWindow]
  /// reps is this many times slower than the set's baseline pace (average
  /// of its first [fatigueRepThreshold] reps). Comparing a rolling average
  /// instead of a single rep means one noisy sample (camera jitter, a brief
  /// pause to adjust position) can't flip the flag on its own — it takes a
  /// sustained slowdown across several reps in a row.
  final double fatigueSlowdownRatio;

  /// How many of the most recent reps are averaged for the fatigue check.
  final int fatigueWindow;

  double? _baseline;
  double? _minDuringDown;
  RepPhase _phase = RepPhase.up;
  int reps = 0;
  int? _repStartMs;
  int? _lastRepDurationMs;
  final List<int> repDurationsMs = [];
  bool _fatigued = false;

  int? get lastRepDurationMs => _lastRepDurationMs;
  bool get isCalibrated => _calibrated;

  void reset() {
    _baseline = null;
    _minDuringDown = null;
    _phase = RepPhase.up;
    reps = 0;
    _repStartMs = null;
    _lastRepDurationMs = null;
    repDurationsMs.clear();
    _fatigued = false;
    // Calibration state deliberately survives reset() — it's carried across
    // sets within the same workout screen session by the caller re-using
    // this instance, so a set that ends right after calibrating doesn't
    // throw away what was just learned.
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
      _minDuringDown = distance;
      return null;
    }

    if (_phase == RepPhase.down) {
      if (_minDuringDown == null || distance < _minDuringDown!) {
        _minDuringDown = distance;
      }

      if (delta < upThreshold) {
        _phase = RepPhase.up;
        final start = _repStartMs;
        final minDuringDown = _minDuringDown;
        _repStartMs = null;
        _minDuringDown = null;
        if (start == null) return null;
        final durationMs = timestampMs - start;
        if (durationMs < minRepMs) return null;
        reps++;
        _lastRepDurationMs = durationMs;
        repDurationsMs.add(durationMs);
        if (minDuringDown != null) _recordAmplitude(_baseline! - minDuringDown);
        // Once flagged, fatigue stays on for the rest of the set instead of
        // flickering off the moment one rep happens to land back near the
        // baseline pace — a real tired set doesn't suddenly stop being tired.
        _fatigued = _fatigued || _isFatigued();
        return RepEvent(reps: reps, durationMs: durationMs, fatigued: _fatigued);
      }
    }

    return null;
  }

  /// Feeds a completed rep's actual range of motion into calibration. Once
  /// [calibrationRepCount] reps have been measured, the thresholds are set
  /// relative to the average amplitude actually observed — clamped to a
  /// sane range so a wildly noisy first few reps can't produce a threshold
  /// too tight or too loose to ever work.
  void _recordAmplitude(double amplitude) {
    if (_calibrated || amplitude <= 0) return;
    _repAmplitudes.add(amplitude);
    if (_repAmplitudes.length < calibrationRepCount) return;

    final avgAmplitude = _repAmplitudes.reduce((a, b) => a + b) / _repAmplitudes.length;
    downThreshold = (avgAmplitude * 0.4).clamp(0.012, 0.05);
    upThreshold = (avgAmplitude * 0.2).clamp(0.006, 0.025);
    _calibrated = true;
    onCalibrated?.call(downThreshold, upThreshold);
  }

  bool _isFatigued() {
    if (reps < fatigueRepThreshold + fatigueWindow) return false;
    final baseline = repDurationsMs.take(fatigueRepThreshold);
    final baselineAvg = baseline.reduce((a, b) => a + b) / baseline.length;
    final recent = repDurationsMs.skip(repDurationsMs.length - fatigueWindow);
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    return recentAvg > baselineAvg * fatigueSlowdownRatio;
  }
}
