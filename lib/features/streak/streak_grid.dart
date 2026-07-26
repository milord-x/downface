import 'package:flutter/cupertino.dart';
import '../../app/theme/glass.dart';

class StreakGrid extends StatelessWidget {
  const StreakGrid({super.key, required this.days, this.weeks = 20});

  final Set<DateTime> days;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final start = todayNorm.subtract(Duration(days: weeks * 7 - 1));
    final firstMonday = start.subtract(Duration(days: (start.weekday - 1)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: List.generate(weeks, (week) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              children: List.generate(7, (day) {
                final date = firstMonday.add(Duration(days: week * 7 + day));
                final active = days.contains(DateTime(date.year, date.month, date.day));
                final isFuture = date.isAfter(todayNorm);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isFuture
                          ? CupertinoColors.transparent
                          : active
                              ? AppColors.white
                              : AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
