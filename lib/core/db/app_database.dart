import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/workout.dart';
import '../models/workout_set.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'flex.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workouts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            startedAt INTEGER NOT NULL,
            endedAt INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sets(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workoutId INTEGER NOT NULL,
            reps INTEGER NOT NULL,
            startedAt INTEGER NOT NULL,
            endedAt INTEGER NOT NULL,
            restBeforeSeconds INTEGER NOT NULL,
            repDurationsMs TEXT NOT NULL,
            FOREIGN KEY(workoutId) REFERENCES workouts(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_sets_workout ON sets(workoutId)');
        await db.execute('CREATE INDEX idx_workouts_startedAt ON workouts(startedAt)');
      },
    );
  }

  Future<int> insertWorkout(Workout workout) async {
    final db = await database;
    return db.transaction((txn) async {
      final workoutId = await txn.insert('workouts', workout.toMap()..remove('id'));
      for (final set in workout.sets) {
        await txn.insert('sets', (set.toMap()..remove('id'))..['workoutId'] = workoutId);
      }
      return workoutId;
    });
  }

  Future<List<Workout>> allWorkouts() async {
    final db = await database;
    final workoutRows = await db.query('workouts', orderBy: 'startedAt DESC');
    final result = <Workout>[];
    for (final row in workoutRows) {
      final setRows = await db.query(
        'sets',
        where: 'workoutId = ?',
        whereArgs: [row['id']],
        orderBy: 'startedAt ASC',
      );
      result.add(Workout.fromMap(row, setRows.map(WorkoutSet.fromMap).toList()));
    }
    return result;
  }

  Future<DateTime?> lastWorkoutDay() async {
    final db = await database;
    final rows = await db.query('workouts', orderBy: 'startedAt DESC', limit: 1);
    if (rows.isEmpty) return null;
    final startedAt = DateTime.fromMillisecondsSinceEpoch(rows.first['startedAt'] as int);
    return DateTime(startedAt.year, startedAt.month, startedAt.day);
  }

  Future<void> wipeAll() async {
    final db = await database;
    await db.delete('sets');
    await db.delete('workouts');
  }

  Future<void> importWorkouts(List<Workout> workouts) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sets');
      await txn.delete('workouts');
      for (final workout in workouts) {
        final workoutId = await txn.insert('workouts', workout.toMap()..remove('id'));
        for (final set in workout.sets) {
          await txn.insert('sets', (set.toMap()..remove('id'))..['workoutId'] = workoutId);
        }
      }
    });
  }
}
