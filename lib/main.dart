import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:smf_app/app/main.dart';
import 'package:smf_app/features/motion/presentation/motion_patterns/pendulum_ball_motion.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) FlutterForegroundTask.initCommunicationPort();
  await SleepRepository.instance.init();
  runApp(const SmfApp());
}
/// flutter_overlay_window の OverlayService から呼ばれるエントリポイント。
///
/// 注意: プラグイン側が「アプリのメインDartエントリ」に対して `overlayMain` を探す実装のため、
/// ここ（`lib/main.dart`）にトップレベル関数として置く必要がある。
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: PendulumBallMotion(period: Duration(milliseconds: 5000)),
      ),
    ),
  );
}
