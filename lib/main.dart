import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:smf_app/app/main.dart';
import 'package:smf_app/features/alarm/application/sleep_task_handler.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';
import 'package:smf_app/features/motion/presentation/motion_patterns/pendulum_ball_motion.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
    _initForegroundTask();
  }

  await SleepRepository.instance.init();
  runApp(const SmfApp());
}

/// 睡眠計測フォアグラウンドサービスの初期化。
/// startService() より前に必ず呼ぶ必要がある。
void _initForegroundTask() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'sleep_recording_channel',
      channelName: '睡眠計測',
      channelDescription: '睡眠計測中はこの通知が表示されます',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      allowWakeLock: true, // 画面オフ中もCPUを起こし続ける
      allowWifiLock: false,
    ),
  );
}

/// flutter_foreground_task のバックグラウンドエントリポイント。
/// sleep_task_handler.dart の sleepRecordingCallback を委譲。
@pragma('vm:entry-point')
void backgroundServiceEntryPoint() => sleepRecordingCallback();

/// flutter_overlay_window の OverlayService から呼ばれるエントリポイント。
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
