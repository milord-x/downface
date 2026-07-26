import 'workout_set.dart';

class Workout {
  const Workout({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
  });

  final int? id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<WorkoutSet> sets;

  int get totalReps => sets.fold(0, (sum, s) => sum + s.reps);

  Duration get totalDuration => endedAt.difference(startedAt);

  DateTime get day => DateTime(startedAt.year, startedAt.month, startedAt.day);

  Map<String, Object?> toMap() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
      };

  factory Workout.fromMap(Map<String, Object?> map, List<WorkoutSet> sets) => Workout(
        id: map['id'] as int?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
        endedAt: DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
        sets: sets,
      );
}
