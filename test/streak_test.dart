import 'package:flutter_test/flutter_test.dart';
import 'package:downface/core/models/streak.dart';

void main() {
  test('current streak counts consecutive days ending today', () {
    final today = DateTime(2026, 7, 27);
    final days = [
      DateTime(2026, 7, 27),
      DateTime(2026, 7, 26),
      DateTime(2026, 7, 25),
      DateTime(2026, 7, 20),
    ];
    final info = computeStreak(days, today);
    expect(info.current, 3);
    expect(info.longest, 3);
    expect(info.brokenToday, false);
  });

  test('streak still alive if only yesterday was logged', () {
    final today = DateTime(2026, 7, 27);
    final days = [DateTime(2026, 7, 26)];
    final info = computeStreak(days, today);
    expect(info.current, 1);
    expect(info.brokenToday, false);
  });

  test('streak broken if gap of 2+ days', () {
    final today = DateTime(2026, 7, 27);
    final days = [DateTime(2026, 7, 24)];
    final info = computeStreak(days, today);
    expect(info.current, 0);
    expect(info.brokenToday, true);
  });

  test('longest streak survives past a broken run', () {
    final today = DateTime(2026, 7, 27);
    final days = [
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 2),
      DateTime(2026, 7, 3),
      DateTime(2026, 7, 4),
      DateTime(2026, 7, 27),
    ];
    final info = computeStreak(days, today);
    expect(info.current, 1);
    expect(info.longest, 4);
  });
}
