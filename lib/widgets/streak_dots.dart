import 'package:flutter/cupertino.dart';
import '../app/theme/glass.dart';

class StreakWeekStrip extends StatelessWidget {
  const StreakWeekStrip({super.key, required this.completedWeekdays, required this.todayWeekday});

  final Set<int> completedWeekdays;
  final int todayWeekday;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final weekday = i + 1;
        final done = completedWeekdays.contains(weekday);
        final isToday = weekday == todayWeekday;
        return Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.white : AppColors.surfaceRaised,
                border: isToday && !done
                    ? Border.all(color: AppColors.white, width: 1.4)
                    : null,
              ),
              child: done
                  ? const Icon(CupertinoIcons.checkmark, size: 16, color: AppColors.black)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              _labels[i],
              style: TextStyle(
                color: isToday ? AppColors.white : AppColors.dim,
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }
}
