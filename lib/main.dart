import 'package:flutter/cupertino.dart';

import 'app/theme/app_theme.dart';
import 'core/app_state.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const FlexApp());
}

class FlexApp extends StatefulWidget {
  const FlexApp({super.key});

  @override
  State<FlexApp> createState() => _FlexAppState();
}

class _FlexAppState extends State<FlexApp> {
  final _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.load();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Downface',
      debugShowCheckedModeBanner: false,
      theme: appCupertinoTheme,
      home: HomeScreen(appState: _appState),
    );
  }
}
