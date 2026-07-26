import 'package:flutter/cupertino.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/glass.dart';
import '../../core/app_state.dart';
import '../../widgets/streak_dots.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../workout/workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = widget.appState;
    final streak = state.streak;
    final weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final completedWeekdays = state.activeDays
        .where((d) => !d.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day)))
        .map((d) => d.weekday)
        .toSet();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => SettingsScreen(appState: state)),
                    ),
                    child: const Icon(CupertinoIcons.gear_alt, color: AppColors.white, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LiquidGlass(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${state.repsToday}',
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text('push-ups\ntoday', style: AppText.title),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: AppColors.stroke),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatColumn(label: 'this week', value: state.repsSince(weekStart)),
                        _StatColumn(
                          label: 'this month',
                          value: state.repsSince(DateTime(DateTime.now().year, DateTime.now().month)),
                        ),
                        _StatColumn(label: 'so far', value: state.repsAllTime),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlass(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('this week', style: AppText.title),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.flame_fill, color: AppColors.white, size: 18),
                            const SizedBox(width: 4),
                            Text('${streak.current}', style: AppText.body),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreakWeekStrip(
                      completedWeekdays: completedWeekdays,
                      todayWeekday: DateTime.now().weekday,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      filled: true,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => WorkoutScreen(appState: state)),
                      ),
                      child: const Center(
                        child: Text(
                          'start workout',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GlassButton(
                    padding: const EdgeInsets.all(18),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => StatsScreen(appState: state)),
                    ),
                    child: const Icon(CupertinoIcons.square_stack_3d_up, color: AppColors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: AppText.caption),
      ],
    );
  }
}
