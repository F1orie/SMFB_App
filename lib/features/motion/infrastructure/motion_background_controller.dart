import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// モーション（視覚刺激）を「バックグラウンドでも継続」させるための制御。
///
/// 仕様の前提:
/// - Android を最優先
/// - 画面点灯を維持し、視覚モーションを動かし続ける（=実質フォアグラウンド維持）
class MotionBackgroundController {
  MotionBackgroundController._();

  static bool _initialized = false;

  static bool get _shouldUseForegroundService =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get _shouldUseOverlay =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    if (_shouldUseForegroundService) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'motion_foreground_service',
          channelName: 'Motion Service',
          channelDescription:
              'This notification appears when motion is running.',
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );
    }
  }

  /// モーションを継続モードにする（Wakelock + ForegroundService）。
  ///
  /// システムオーバーレイは **ここでは出さない**（前面利用時にアプリ上へ二重表示になるため）。
  /// バックグラウンド移行時は [showOverlayWhenAppBackgrounded] を呼ぶ。
  static Future<void> enable() async {
    _ensureInitialized();

    await WakelockPlus.enable();

    // バックグラウンド用オーバーレイ権限は前面で取得しておく（表示はしない）。
    if (_shouldUseOverlay) {
      var granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        await FlutterOverlayWindow.requestPermission();
      }
    }

    if (!_shouldUseForegroundService) return;

    if (await FlutterForegroundTask.isRunningService) return;

    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 512,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'モーション実行中',
      notificationText: 'タップしてアプリに戻る',
      notificationIcon: null,
      notificationInitialRoute: '/',
      callback: _startCallback,
    );

    switch (result) {
      case ServiceRequestSuccess():
        break;
      case ServiceRequestFailure(:final error):
        debugPrint(
          'MotionBackgroundController: foreground service failed: $error',
        );
    }
  }

  /// 前面表示用にシステムオーバーレイを閉じる（アプリ内シェルと二重にならないようにする）。
  static Future<void> hideOverlayForInAppExperience() async {
    if (!_shouldUseOverlay) return;
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  /// アプリが背後に回ったとき、他アプリ上に振り子を出す（権限があれば）。
  static Future<void> showOverlayWhenAppBackgrounded() async {
    if (!_shouldUseOverlay) return;
    _ensureInitialized();
    if (await FlutterOverlayWindow.isActive()) return;

    var granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      await FlutterOverlayWindow.requestPermission();
      granted = await FlutterOverlayWindow.isPermissionGranted();
    }
    if (!granted) return;

    await FlutterOverlayWindow.showOverlay(
      height: WindowSize.fullCover,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      flag: OverlayFlag.clickThrough,
      overlayTitle: 'モーション表示中',
      overlayContent: 'タップは下のアプリに届きます',
    );
  }

  /// 継続モードを解除する（ForegroundService 停止 + Wakelock解除）。
  static Future<void> disable() async {
    _ensureInitialized();

    if (_shouldUseForegroundService &&
        await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    if (_shouldUseOverlay && await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }

    await WakelockPlus.disable();
  }

  /// Android でシステムオーバーレイを使うか（ライフサイクル連動の分岐用）。
  static bool get triesSystemOverlay =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_MotionTaskHandler());
}

class _MotionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
