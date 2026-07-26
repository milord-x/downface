class WorkoutSet {
  const WorkoutSet({
    required this.id,
    required this.workoutId,
    required this.reps,
    required this.startedAt,
    required this.endedAt,
    required this.restBeforeSeconds,
    required this.repDurationsMs,
  });

  final int? id;
  final int workoutId;
  final int reps;
  final DateTime startedAt;
  final DateTime endedAt;
  final int restBeforeSeconds;
  final List<int> repDurationsMs;

  Duration get duration => endedAt.difference(startedAt);

  double get averageRepDurationMs =>
      repDurationsMs.isEmpty ? 0 : repDurationsMs.reduce((a, b) => a + b) / repDurationsMs.length;

  Map<String, Object?> toMap() => {
        'id': id,
        'workoutId': workoutId,
        'reps': reps,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'restBeforeSeconds': restBeforeSeconds,
        'repDurationsMs': repDurationsMs.join(','),
      };

  factory WorkoutSet.fromMap(Map<String, Object?> map) => WorkoutSet(
        id: map['id'] as int?,
        workoutId: map['workoutId'] as int,
        reps: map['reps'] as int,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
        endedAt: DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
        restBeforeSeconds: map['restBeforeSeconds'] as int,
        repDurationsMs: (map['repDurationsMs'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
      );
}
