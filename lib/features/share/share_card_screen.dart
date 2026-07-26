import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/glass.dart';
import '../../core/app_state.dart';

class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = await _writeTemp(dir.path, bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(files: [XFile(file)]));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<String> _writeTemp(String dirPath, Uint8List bytes) async {
    final path = '$dirPath/flex_stats.png';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.appState;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.black,
        border: null,
        middle: const Text('share', style: AppText.title),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              RepaintBoundary(
                key: _boundaryKey,
                child: _StatCard(
                  reps: state.repsAllTime,
                  streak: state.streak.current,
                  workouts: state.workouts.length,
                ),
              ),
              const Spacer(),
              GlassButton(
                filled: true,
                onTap: _sharing ? () {} : _share,
                child: Text(
                  _sharing ? 'preparing…' : 'share',
                  style: const TextStyle(color: AppColors.black, fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.reps, required this.streak, required this.workouts});
  final int reps;
  final int streak;
  final int workouts;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.black,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('FLEX', style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$reps', style: AppText.number.copyWith(fontSize: 72)),
                const Text('total push-ups', style: AppText.caption),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniStat(label: 'streak', value: '$streak d'),
                _MiniStat(label: 'workouts', value: '$workouts'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: AppText.caption),
      ],
    );
  }
}
