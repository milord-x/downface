import 'package:flutter/cupertino.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/glass.dart';
import '../../core/app_state.dart';
import '../streak/streak_grid.dart';
import '../share/share_card_screen.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final workouts = appState.workouts;
    final durations = workouts
        .expand((w) => w.sets)
        .map((s) => s.averageRepDurationMs)
        .where((d) => d > 0)
        .toList();
    final avgRepMs = durations.isEmpty ? 0 : durations.reduce((a, b) => a + b) / durations.length;
    final rests = workouts.expand((w) => w.sets).map((s) => s.restBeforeSeconds).where((r) => r > 0).toList();
    final avgRest = rests.isEmpty ? 0 : rests.reduce((a, b) => a + b) / rests.length;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.black,
        border: null,
        middle: const Text('stats', style: AppText.title),
        trailing: GestureDetector(
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => ShareCardScreen(appState: appState)),
          ),
          child: const Icon(CupertinoIcons.square_arrow_up, color: AppColors.white),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LiquidGlass(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('activity', style: AppText.title),
                  const SizedBox(height: 16),
                  StreakGrid(days: appState.activeDays),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(label: 'avg rep', value: '${(avgRepMs / 1000).toStringAsFixed(1)}s'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(label: 'avg rest', value: '${avgRest.round()}s'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(label: 'longest streak', value: '${appState.streak.longest}d'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(label: 'total workouts', value: '${workouts.length}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }
}
