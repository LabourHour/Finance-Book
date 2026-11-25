import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  // 先完成初始化（应用锁状态、周期记账补记、预算与回收站），
  // 避免冷启动时先渲染主界面再被锁屏覆盖，造成隐私露出。
  await state.initialize();
  runApp(StreamApp(state: state));
}