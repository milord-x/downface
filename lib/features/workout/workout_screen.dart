import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/glass.dart';
import '../../core/app_state.dart';
import '../../core/models/workout.dart';
import '../../core/models/workout_set.dart';
import 'face_distance_source.dart';
import 'rep_counter.dart';

enum _Stage { ready, tracking, resting, finished }

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _source = FaceDistanceSource();
  final _counter = RepCounter();
  final _sets = <WorkoutSet>[];

  StreamSubscription<FaceSample>? _sub;
  _Stage _stage = _Stage.ready;
  DateTime? _setStart;
  int _restSeconds = 0;
  Timer? _restTimer;
  bool _supported = true;
  late DateTime _workoutStart;

  @override
  void initState() {
    super.initState();
    _workoutStart = DateTime.now();
    _source.isSupported().then((value) {
      if (mounted) setState(() => _supported = value);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _restTimer?.cancel();
    _source.stop();
    super.dispose();
  }

  Future<void> _startSet() async {
    _counter.reset();
    _setStart = DateTime.now();
    await _source.start();
    _sub = _source.samples().listen((sample) {
      final event = _counter.onDistanceSample(sample.distance, sample.timestampMs);
      if (event != null && mounted) setState(() {});
    });
    setState(() => _stage = _Stage.tracking);
  }

  Future<void> _endSet() async {
    await _source.stop();
    await _sub?.cancel();
    final start = _setStart!;
    _sets.add(WorkoutSet(
      id: null,
      workoutId: 0,
      reps: _counter.reps,
      startedAt: start,
      endedAt: DateTime.now(),
      restBeforeSeconds: _restSeconds,
      repDurationsMs: _counter.lastRepDurationMs == null ? [] : [_counter.lastRepDurationMs!],
    ));
    setState(() => _stage = _Stage.resting);
    _restSeconds = 0;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _restSeconds++);
    });
  }

  Future<void> _finish() async {
    _restTimer?.cancel();
    if (_sets.isNotEmpty) {
      await widget.appState.addWorkout(Workout(
        id: null,
        startedAt: _workoutStart,
        endedAt: DateTime.now(),
        sets: _sets,
      ));
    }
    setState(() => _stage = _Stage.finished);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildStage(),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.ready:
        return _ReadyView(supported: _supported, onStart: _startSet);
      case _Stage.tracking:
        return _TrackingView(reps: _counter.reps, onEndSet: _endSet);
      case _Stage.resting:
        return _RestingView(
          seconds: _restSeconds,
          setsSoFar: _sets.length,
          onNextSet: _startSet,
          onFinish: _finish,
        );
      case _Stage.finished:
        return _FinishedView(sets: _sets, onDone: () => Navigator.of(context).pop());
    }
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.supported, required this.onStart});
  final bool supported;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CupertinoIcons.device_phone_portrait, color: AppColors.white, size: 64),
        const SizedBox(height: 24),
        const Text(
          'place your phone on the floor\nscreen facing you',
          textAlign: TextAlign.center,
          style: AppText.title,
        ),
        const SizedBox(height: 12),
        const Text(
          'Flex tracks your head with the TrueDepth camera',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
        const SizedBox(height: 40),
        if (!supported)
          const Text(
            'This device has no TrueDepth camera',
            style: TextStyle(color: AppColors.dim),
          )
        else
          GlassButton(
            filled: true,
            onTap: onStart,
            child: const Text(
              'begin set',
              style: TextStyle(color: AppColors.black, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _TrackingView extends StatelessWidget {
  const _TrackingView({required this.reps, required this.onEndSet});
  final int reps;
  final VoidCallback onEndSet;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$reps', style: AppText.number.copyWith(fontSize: 96)),
        const SizedBox(height: 8),
        const Text('reps', style: AppText.caption),
        const Spacer(),
        GlassButton(
          filled: true,
          onTap: onEndSet,
          child: const Text(
            'end set',
            style: TextStyle(color: AppColors.black, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _RestingView extends StatelessWidget {
  const _RestingView({
    required this.seconds,
    required this.setsSoFar,
    required this.onNextSet,
    required this.onFinish,
  });

  final int seconds;
  final int setsSoFar;
  final VoidCallback onNextSet;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$seconds s', style: AppText.number),
        const SizedBox(height: 8),
        Text('rest · $setsSoFar set${setsSoFar == 1 ? '' : 's'} done', style: AppText.caption),
        const Spacer(),
        GlassButton(
          filled: true,
          onTap: onNextSet,
          child: const Text(
            'next set',
            style: TextStyle(color: AppColors.black, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        GlassButton(
          onTap: onFinish,
          child: const Text('finish workout', style: TextStyle(color: AppColors.white, fontSize: 17)),
        ),
      ],
    );
  }
}

class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.sets, required this.onDone});
  final List<WorkoutSet> sets;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final total = sets.fold(0, (sum, s) => sum + s.reps);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CupertinoIcons.checkmark_circle, color: AppColors.white, size: 64),
        const SizedBox(height: 20),
        Text('$total reps', style: AppText.number),
        const SizedBox(height: 8),
        Text('${sets.length} sets logged', style: AppText.caption),
        const Spacer(),
        GlassButton(
          filled: true,
          onTap: onDone,
          child: const Text('done', style: TextStyle(color: AppColors.black, fontSize: 17, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
