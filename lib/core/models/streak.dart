class StreakInfo {
  const StreakInfo({required this.current, required this.longest, required this.brokenToday});

  final int current;
  final int longest;
  final bool brokenToday;
}

StreakInfo computeStreak(List<DateTime> workoutDays, DateTime today) {
  final days = workoutDays.map((d) => DateTime(d.year, d.month, d.day)).toSet();
  final todayNorm = DateTime(today.year, today.month, today.day);

  var cursor = days.contains(todayNorm) ? todayNorm : todayNorm.subtract(const Duration(days: 1));
  var current = 0;
  while (days.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  final sorted = days.toList()..sort();
  var longest = 0;
  var run = 0;
  DateTime? prev;
  for (final d in sorted) {
    if (prev != null && d.difference(prev).inDays == 1) {
      run++;
    } else {
      run = 1;
    }
    longest = run > longest ? run : longest;
    prev = d;
  }

  final brokenToday = !days.contains(todayNorm) &&
      !days.contains(todayNorm.subtract(const Duration(days: 1)));

  return StreakInfo(current: current, longest: longest, brokenToday: brokenToday);
}
