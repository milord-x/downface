import 'package:shared_preferences/shared_preferences.dart';

/// Persists the rep counter's calibrated thresholds across app restarts,
/// so a user's measured range of motion only needs to be learned once
/// rather than every time the app is relaunched.
class ThresholdCalibrationService {
  static const _downKey = 'calibrated_down_threshold';
  static const _upKey = 'calibrated_up_threshold';

  Future<(double, double)?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final down = prefs.getDouble(_downKey);
    final up = prefs.getDouble(_upKey);
    if (down == null || up == null) return null;
    return (down, up);
  }

  Future<void> save(double downThreshold, double upThreshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_downKey, downThreshold);
    await prefs.setDouble(_upKey, upThreshold);
  }
}
