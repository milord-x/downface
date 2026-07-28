import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'core/app_state.dart';
import 'core/export/backup_codec.dart';
import 'core/export/backup_service.dart';
import 'core/models/workout.dart';
import 'core/models/workout_set.dart';
import 'features/workout/face_distance_source.dart';
import 'features/workout/rep_counter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NativeBridge().start();
}

class NativeBridge {
  static const _channel = MethodChannel('downface/native_ui');

  final _appState = AppState();
  final _backup = BackupService();
  final _faceSource = FaceDistanceSource();
  final _repCounter = RepCounter();

  DateTime? _workoutStart;
  DateTime? _setStart;
  final _sets = <WorkoutSet>[];
  int _restSeconds = 0;
  int _restToken = 0;

  Future<void> start() async {
    _channel.setMethodCallHandler(_onNativeCall);
    await _appState.load();
    _pushSnapshot();
    final supported = await _faceSource.isSupported();
    _channel.invokeMethod('workoutReady', {'supported': supported});
  }

  void _pushSnapshot() {
    _channel.invokeMethod('updateSnapshot', _appState.toSnapshotJson());
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'startSet':
        await _startSet();
      case 'endSet':
        await _endSet();
      case 'finishWorkout':
        await _finishWorkout();
      case 'cancelWorkout':
        await _cancelWorkout();
      case 'exportBackup':
        final file = await _backup.exportToFile();
        _channel.invokeMethod('shareFile', {'path': file.path});
      case 'importBackup':
        await _importBackup();
      case 'wipeData':
        await _appState.replaceAll([]);
        _pushSnapshot();
      case 'setReminders':
        final args = call.arguments as Map<dynamic, dynamic>;
        final minutes = (args['minutes'] as List<dynamic>).cast<int>();
        await _appState.setReminders(args['enabled'] as bool, minutes);
        _pushSnapshot();
      case 'declineReminders':
        await _appState.declineReminders();
        _pushSnapshot();
    }
    return null;
  }

  static const _staleWorkoutGap = Duration(hours: 2);

  Future<void> _startSet() async {
    _restToken++;
    if (_workoutStart != null && DateTime.now().difference(_setStart ?? _workoutStart!) > _staleWorkoutGap) {
      _sets.clear();
      _workoutStart = null;
    }
    _workoutStart ??= DateTime.now();
    _repCounter.reset();
    _setStart = DateTime.now();
    await _faceSource.start();
    _faceSource.samples().listen((sample) {
      final event = _repCounter.onDistanceSample(sample.distance, sample.timestampMs);
      if (event != null) {
        _channel.invokeMethod('workoutTracking', {'reps': _repCounter.reps, 'fatigued': event.fatigued});
      }
    });
    _channel.invokeMethod('workoutTracking', {'reps': 0});
  }

  Future<void> _endSet() async {
    await _faceSource.stop();
    final start = _setStart;
    if (start == null) return;
    _sets.add(WorkoutSet(
      id: null,
      workoutId: 0,
      reps: _repCounter.reps,
      startedAt: start,
      endedAt: DateTime.now(),
      restBeforeSeconds: _restSeconds,
      repDurationsMs: List.of(_repCounter.repDurationsMs),
    ));
    _restSeconds = 0;
    _restToken++;
    _channel.invokeMethod('workoutResting', {'seconds': 0, 'setsSoFar': _sets.length});
    _tickRest(_restToken);
  }

  Future<void> _tickRest(int token) async {
    while (token == _restToken) {
      await Future.delayed(const Duration(seconds: 1));
      if (token != _restToken) return;
      _restSeconds++;
      _channel.invokeMethod('workoutResting', {'seconds': _restSeconds, 'setsSoFar': _sets.length});
    }
  }

  Future<void> _finishWorkout() async {
    _restToken++;
    final start = _workoutStart;
    final end = DateTime.now();
    if (start != null && _sets.isNotEmpty) {
      await _appState.addWorkout(Workout(
        id: null,
        startedAt: start,
        endedAt: end,
        sets: List.of(_sets),
      ));
      _pushSnapshot();
    }
    final totalReps = _sets.fold(0, (sum, s) => sum + s.reps);
    final setCount = _sets.length;
    _sets.clear();
    _workoutStart = null;
    _channel.invokeMethod('workoutFinished', {
      'totalReps': totalReps,
      'sets': setCount,
      'startedAt': (start ?? end).millisecondsSinceEpoch.toDouble(),
      'endedAt': end.millisecondsSinceEpoch.toDouble(),
    });
  }

  Future<void> _cancelWorkout() async {
    _restToken++;
    await _faceSource.stop();
    _sets.clear();
    _workoutStart = null;
    _setStart = null;
    _restSeconds = 0;
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    try {
      await _backup.importFromFile(File(result.files.single.path!));
      await _appState.load();
      _pushSnapshot();
    } on TamperedBackupException {
      // surfaced to user via native alert in a future iteration
    }
  }
}
