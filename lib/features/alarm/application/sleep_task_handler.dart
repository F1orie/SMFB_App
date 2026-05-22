import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// flutter_foreground_task のエントリポイント。
/// main.dart と同じファイルに置けないため、ここに定義してmain.dartからimportする。
@pragma('vm:entry-point')
void sleepRecordingCallback() {
  FlutterForegroundTask.setTaskHandler(SleepTaskHandler());
}

/// 睡眠計測中にフォアグラウンドサービスを維持するだけのハンドラ。
/// 実際のセンサー計測は SleepRecorderService（メインアイソレート）が担当。
class SleepTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // センサー読み取りはメインアイソレートで行うため、ここでは何もしない
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 定期タスクなし
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
