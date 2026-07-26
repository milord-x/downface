import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/glass.dart';
import '../../core/app_state.dart';
import '../../core/export/backup_codec.dart';
import '../../core/export/backup_service.dart';
import '../../core/reminders_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _reminders = RemindersService();
  final _backup = BackupService();
  bool _remindersOn = false;
  int _reminderHour = 19;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reminders.isEnabled().then((v) => setState(() => _remindersOn = v));
    _reminders.hour().then((h) => setState(() => _reminderHour = h));
  }

  Future<void> _toggleReminders(bool value) async {
    await _reminders.setEnabled(value, hour: _reminderHour);
    setState(() => _remindersOn = value);
  }

  Future<void> _export() async {
    await _backup.shareBackup();
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    try {
      await _backup.importFromFile(File(result.files.single.path!));
      await widget.appState.load();
      setState(() => _status = 'Backup restored');
    } on TamperedBackupException {
      setState(() => _status = 'This file was modified or is not a Flex backup');
    } catch (_) {
      setState(() => _status = 'Could not read this file');
    }
  }

  Future<void> _wipe() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete all data'),
        content: const Text('This removes every workout on this device. This cannot be undone.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.appState.replaceAll([]);
      setState(() => _status = 'All data deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.black,
        border: null,
        middle: const Text('settings', style: AppText.title),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            LiquidGlass(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Daily reminder', style: AppText.body)),
                  CupertinoSwitch(value: _remindersOn, onChanged: _toggleReminders),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('backup', style: AppText.caption),
            const SizedBox(height: 8),
            LiquidGlass(
              child: Column(
                children: [
                  _SettingsRow(label: 'Export backup file', onTap: _export),
                  Container(height: 1, color: AppColors.stroke),
                  _SettingsRow(label: 'Import backup file', onTap: _import),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('data', style: AppText.caption),
            const SizedBox(height: 8),
            LiquidGlass(
              child: _SettingsRow(label: 'Delete all data', onTap: _wipe, destructive: true),
            ),
            if (_status != null) ...[
              const SizedBox(height: 16),
              Text(_status!, style: AppText.caption, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.onTap, this.destructive = false});
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          label,
          style: TextStyle(
            color: destructive ? CupertinoColors.destructiveRed : AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
