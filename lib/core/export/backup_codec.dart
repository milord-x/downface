import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/workout.dart';
import '../models/workout_set.dart';

class TamperedBackupException implements Exception {
  const TamperedBackupException();
  @override
  String toString() => 'Backup file failed integrity check';
}

class BackupCodec {
  static const _magic = 'FLEXBAK1';
  static const _appSecret =
      'a4f0c9e2517b4d6a9f0e8c2a7d6b1e4f9c3a8d7e0b5f2c1a6d9e4b7c0f3a8d1e';

  static final _algorithm = AesGcm.with256bits();

  static Future<Uint8List> encode(List<Workout> workouts) async {
    final json = jsonEncode(workouts
        .map((w) => {
              'startedAt': w.startedAt.millisecondsSinceEpoch,
              'endedAt': w.endedAt.millisecondsSinceEpoch,
              'sets': w.sets
                  .map((s) => {
                        'reps': s.reps,
                        'startedAt': s.startedAt.millisecondsSinceEpoch,
                        'endedAt': s.endedAt.millisecondsSinceEpoch,
                        'restBeforeSeconds': s.restBeforeSeconds,
                        'repDurationsMs': s.repDurationsMs,
                      })
                  .toList(),
            })
        .toList());

    final plaintext = utf8.encode(json);
    final secretKey = await _deriveKey();
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(plaintext, secretKey: secretKey, nonce: nonce);

    final out = BytesBuilder();
    out.add(utf8.encode(_magic));
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  static Future<List<Workout>> decode(Uint8List file) async {
    if (file.length < 8 + 12 + 16) throw const TamperedBackupException();
    final magic = utf8.decode(file.sublist(0, 8));
    if (magic != _magic) throw const TamperedBackupException();

    final nonce = file.sublist(8, 20);
    final mac = file.sublist(file.length - 16);
    final cipherText = file.sublist(20, file.length - 16);

    final secretKey = await _deriveKey();
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

    late final List<int> plaintext;
    try {
      plaintext = await _algorithm.decrypt(box, secretKey: secretKey);
    } catch (_) {
      throw const TamperedBackupException();
    }

    final decoded = jsonDecode(utf8.decode(plaintext)) as List<dynamic>;
    return decoded.map((raw) {
      final map = raw as Map<String, dynamic>;
      final sets = (map['sets'] as List<dynamic>)
          .map((raw) {
            final s = raw as Map<String, dynamic>;
            return WorkoutSet(
              id: null,
              workoutId: 0,
              reps: s['reps'] as int,
              startedAt: DateTime.fromMillisecondsSinceEpoch(s['startedAt'] as int),
              endedAt: DateTime.fromMillisecondsSinceEpoch(s['endedAt'] as int),
              restBeforeSeconds: s['restBeforeSeconds'] as int,
              repDurationsMs: (s['repDurationsMs'] as List<dynamic>).cast<int>(),
            );
          })
          .toList();
      return Workout(
        id: null,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['startedAt'] as int),
        endedAt: DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int),
        sets: sets,
      );
    }).toList();
  }

  static Future<SecretKey> _deriveKey() async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(_appSecret)),
      info: utf8.encode('flex-backup-v1'),
      nonce: utf8.encode('flex-static-salt'),
    );
  }
}
