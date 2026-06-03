import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:smf_app/app/main.dart';
import 'package:smf_app/features/alarm/application/sleep_task_handler.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smf_app/features/motion/application/motion_state.dart';
import 'package:smf_app/features/motion/presentation/motion_pattern_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
    _initForegroundTask();
  }

  await SleepRepository.instance.init();
  await MotionState.loadColors();
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

/// flutter_overlay_window のエントリポイント。
/// 初期パターンをSharedPreferencesから読み、その後はshareData()で動的に切り替え可能。
@pragma('vm:entry-point')
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final initialPattern = prefs.getString('motion_selected_pattern') ?? 'pendulum';
  final def = motionPatterns.firstWhere(
    (p) => p.id == initialPattern, orElse: () => motionPatterns.first);
  final savedColorInt = prefs.getInt('motion_color_$initialPattern');
  final initialColor = savedColorInt != null ? Color(savedColorInt) : def.defaultColor;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _OverlayShell(initialPattern: initialPattern, initialColor: initialColor),
  ));
}

class _OverlayShell extends StatefulWidget {
  const _OverlayShell({required this.initialPattern, required this.initialColor});
  final String initialPattern;
  final Color initialColor;

  @override
  State<_OverlayShell> createState() => _OverlayShellState();
}

class _OverlayShellState extends State<_OverlayShell> {
  late String _pattern;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _pattern = widget.initialPattern;
    _color = widget.initialColor;
    // アプリ側から shareData() で "patternId|colorARGB" 形式で受信
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is String && mounted) {
        final parts = data.split('|');
        setState(() {
          _pattern = parts[0];
          if (parts.length > 1) {
            final colorInt = int.tryParse(parts[1]);
            if (colorInt != null) _color = Color(colorInt);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _overlayWidget(_pattern, _color),
    );
  }
}

Widget _overlayWidget(String patternId, Color color) {
  final def = motionPatterns.firstWhere(
    (p) => p.id == patternId,
    orElse: () => motionPatterns.first,
  );
  return def.build(color);
}
