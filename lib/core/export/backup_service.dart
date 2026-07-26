import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/app_database.dart';
import 'backup_codec.dart';

class BackupService {
  const BackupService();

  Future<File> exportToFile() async {
    final workouts = await AppDatabase.instance.allWorkouts();
    final bytes = await BackupCodec.encode(workouts);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/flex_backup.flexbak');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareBackup() async {
    final file = await exportToFile();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Flex backup'),
    );
  }

  Future<void> importFromFile(File file) async {
    final bytes = await file.readAsBytes();
    final workouts = await BackupCodec.decode(bytes);
    await AppDatabase.instance.importWorkouts(workouts);
  }
}
