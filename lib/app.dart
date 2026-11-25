import 'package:flutter/material.dart';

import 'app_state.dart';
import 'design/stream_theme.dart';
import 'ui/lock_screen.dart';
import 'ui/main_screen.dart';

class StreamApp extends StatelessWidget {
  const StreamApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      // 用 builder 包裹 Navigator，让底部面板与弹窗也能拿到 StreamPalette。
      child: MaterialApp(
        title: 'Stream',
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final currentState = AppScope.of(context);
          final darkMode = switch (currentState.themeMode) {
            ThemeMode.system => null,
            ThemeMode.light => false,
            ThemeMode.dark => true,
          };
          return StreamTheme(darkMode: darkMode, child: child);
        },
        home: const LockGate(child: MainScreen()),
      ),
    );
  }
}