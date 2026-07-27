import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import 'backup_codec.dart';

class BackupService {
  const BackupService();

  Future<File> exportToFile() async {
    final workouts = await AppDatabase.instance.allWorkouts();
    final bytes = await BackupCodec.encode(workouts);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/downface_backup.dfbak');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> importFromFile(File file) async {
    final bytes = await file.readAsBytes();
    final workouts = await BackupCodec.decode(bytes);
    await AppDatabase.instance.importWorkouts(workouts);
  }
}
