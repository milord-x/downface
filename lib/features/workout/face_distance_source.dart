import 'package:flutter/services.dart';

class FaceSample {
  const FaceSample({required this.distance, required this.timestampMs});
  final double distance;
  final int timestampMs;
}

class FaceDistanceSource {
  static const _methods = MethodChannel('flex/face_tracking');
  static const _events = EventChannel('flex/face_distance');

  Future<bool> isSupported() async {
    final supported = await _methods.invokeMethod<bool>('isSupported');
    return supported ?? false;
  }

  Future<void> start() => _methods.invokeMethod('start');

  Future<void> stop() => _methods.invokeMethod('stop');

  Stream<FaceSample> samples() {
    return _events.receiveBroadcastStream().map((event) {
      final map = event as Map<dynamic, dynamic>;
      return FaceSample(
        distance: map['distance'] as double,
        timestampMs: map['timestampMs'] as int,
      );
    });
  }
}
