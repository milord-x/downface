import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flex/core/export/backup_codec.dart';
import 'package:flex/core/models/workout.dart';
import 'package:flex/core/models/workout_set.dart';

void main() {
  final sample = [
    Workout(
      id: null,
      startedAt: DateTime(2026, 7, 20, 8),
      endedAt: DateTime(2026, 7, 20, 8, 10),
      sets: [
        WorkoutSet(
          id: null,
          workoutId: 0,
          reps: 20,
          startedAt: DateTime(2026, 7, 20, 8),
          endedAt: DateTime(2026, 7, 20, 8, 2),
          restBeforeSeconds: 0,
          repDurationsMs: [900, 950, 1000],
        ),
      ],
    ),
  ];

  test('encodes and decodes round trip', () async {
    final bytes = await BackupCodec.encode(sample);
    final decoded = await BackupCodec.decode(bytes);
    expect(decoded.length, 1);
    expect(decoded.first.totalReps, 20);
    expect(decoded.first.sets.first.repDurationsMs, [900, 950, 1000]);
  });

  test('rejects a flipped byte in the ciphertext', () async {
    final bytes = await BackupCodec.encode(sample);
    final tampered = Uint8List.fromList(bytes);
    tampered[tampered.length - 20] ^= 0xFF;
    expect(
      () => BackupCodec.decode(tampered),
      throwsA(isA<TamperedBackupException>()),
    );
  });

  test('rejects a file with wrong magic header', () async {
    final bytes = await BackupCodec.encode(sample);
    final tampered = Uint8List.fromList(bytes);
    tampered[0] = 'X'.codeUnitAt(0);
    expect(
      () => BackupCodec.decode(tampered),
      throwsA(isA<TamperedBackupException>()),
    );
  });
}
