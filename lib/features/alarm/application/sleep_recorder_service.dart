import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../domain/depth_scoring.dart';
import '../domain/sleep_epoch.dart';
import '../domain/sleep_metrics.dart';
import '../domain/sleep_session.dart';
import 'sleep_task_handler.dart';

enum RecorderState { idle, recording, finishing }

class SleepRecordResult {
  const SleepRecordResult({
    required this.session,
    required this.epochs,
    required this.metrics,
  });

  final SleepSession session;
  final List<SleepEpoch> epochs;
  final SleepMetrics metrics;
}

class SleepRecorderService {
  SleepRecorderService();

  /// エポック間隔: デバッグ時は10秒、本番は60秒
  static const int _epochDurationSec = kDebugMode ? 10 : 60;

  /// activityCount の正規化係数 (m/s²)
  /// 設定画面から setNormFactor() で変更可能。
  /// 低め（鈍感）= 3.0 / 標準 = 2.0 / 高め（敏感）= 1.0
  double _accelNormFactor = 2.0;

  /// フォアグラウンドサービスの通知ID
  static const int _serviceId = 256;

  final ValueNotifier<RecorderState> stateNotifier =
      ValueNotifier<RecorderState>(RecorderState.idle);

  SleepSession? _currentSession;
  final List<SleepEpoch> _epochs = [];
  Timer? _epochTimer;
  StreamSubscription<UserAccelerometerEvent>? _accelSub;

  /// エポック内の加速度サンプル蓄積バッファ
  final List<double> _accelSamples = [];

  /// 入眠時刻（一度検出したら更新しない）
  int? _sleepOnsetEpochMs;

  SleepSession? get currentSession => _currentSession;
  List<SleepEpoch> get epochs => List.unmodifiable(_epochs);

  /// センサー感度の正規化係数を更新する。
  /// 低め（鈍感）= 3.0 / 標準 = 2.0 / 高め（敏感）= 1.0
  void setNormFactor(double factor) {
    _accelNormFactor = factor.clamp(1.0, 3.0);
  }

  // ── 開始 ────────────────────────────────────────────────────

  Future<void> start({int? alarmTimeEpochMs}) async {
    if (stateNotifier.value == RecorderState.recording) return;

    final int now = DateTime.now().millisecondsSinceEpoch;
    _sleepOnsetEpochMs = null;

    _currentSession = SleepSession(
      id: 'session_$now',
      startAtEpochMs: now,
      alarmTimeEpochMs: alarmTimeEpochMs,
      status: SleepSessionStatus.recording,
      algoVersion: DepthScoring.algoVersion,
      samplingPeriodSec: _epochDurationSec,
      tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      appVersion: '0.1.0',
      syncState: 'local_only',
    );

    _epochs.clear();
    _accelSamples.clear();
    stateNotifier.value = RecorderState.recording;

    // センサー購読開始
    _startSensor();

    // エポックタイマー
    _epochTimer = Timer.periodic(
      Duration(seconds: _epochDurationSec),
      (_) => _commitEpoch(),
    );

    // フォアグラウンドサービス開始（Android のみ）
    if (!kIsWeb) {
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: '睡眠計測中',
        notificationText: 'STOPを押して計測を終了してください',
        callback: sleepRecordingCallback,
      );
    }
  }

  // ── センサー購読 ─────────────────────────────────────────────

  void _startSensor() {
    if (kIsWeb) return;

    _accelSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval, // ~200ms
    ).listen(
      (event) {
        final double magnitude =
            sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
        _accelSamples.add((magnitude / _accelNormFactor).clamp(0.0, 1.0));
      },
      onError: (_) {
        // センサー取得失敗時はサンプルを追加しない（activityCount=0扱い）
      },
    );
  }

  // ── エポック確定 ─────────────────────────────────────────────

  void _commitEpoch() {
    final SleepSession? session = _currentSession;
    if (session == null) return;

    final double activityCount = _accelSamples.isEmpty
        ? 0.0
        : _accelSamples.reduce((a, b) => a + b) / _accelSamples.length;
    _accelSamples.clear();

    final double scoreDepth = DepthScoring.calculateScoreDepth(activityCount);

    _epochs.add(
      SleepEpoch(
        sessionId: session.id,
        tEpochMs: DateTime.now().millisecondsSinceEpoch,
        activityCount: activityCount,
        scoreDepth: scoreDepth,
      ),
    );

    _detectSleepOnset();
  }

  // ── 入眠検出 ─────────────────────────────────────────────────

  void _detectSleepOnset() {
    if (_sleepOnsetEpochMs != null) return;
    if (_epochs.length < DepthScoring.onsetConsecutive) return;

    final recent = _epochs.sublist(
      _epochs.length - DepthScoring.onsetConsecutive,
    );
    final allDeep =
        recent.every((e) => e.scoreDepth >= DepthScoring.onsetThreshold);

    if (allDeep) {
      _sleepOnsetEpochMs = recent.first.tEpochMs;
    }
  }

  // ── 停止 ────────────────────────────────────────────────────

  Future<SleepRecordResult?> stop() async {
    if (stateNotifier.value != RecorderState.recording) return null;

    stateNotifier.value = RecorderState.finishing;
    _epochTimer?.cancel();
    _epochTimer = null;
    _accelSub?.cancel();
    _accelSub = null;

    // フォアグラウンドサービス停止
    if (!kIsWeb) {
      await FlutterForegroundTask.stopService();
    }

    final SleepSession? session = _currentSession;
    if (session == null) {
      stateNotifier.value = RecorderState.idle;
      return null;
    }

    final SleepSession finishedSession = SleepSession(
      id: session.id,
      startAtEpochMs: session.startAtEpochMs,
      endAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      alarmTimeEpochMs: session.alarmTimeEpochMs,
      sleepOnsetEpochMs: _sleepOnsetEpochMs,
      status: SleepSessionStatus.finished,
      algoVersion: session.algoVersion,
      samplingPeriodSec: session.samplingPeriodSec,
      tzOffsetMin: session.tzOffsetMin,
      appVersion: session.appVersion,
      syncState: session.syncState,
    );

    final SleepMetrics metrics = SleepMetricsCalculator.calculate(
      session: finishedSession,
      epochs: _epochs,
    );

    _currentSession = null;
    _sleepOnsetEpochMs = null;
    stateNotifier.value = RecorderState.idle;

    return SleepRecordResult(
      session: finishedSession,
      epochs: List.unmodifiable(_epochs),
      metrics: metrics,
    );
  }

  // ── 中断 ────────────────────────────────────────────────────

  Future<void> abort() async {
    _epochTimer?.cancel();
    _epochTimer = null;
    _accelSub?.cancel();
    _accelSub = null;
    if (!kIsWeb) await FlutterForegroundTask.stopService();
    _currentSession = null;
    _epochs.clear();
    _accelSamples.clear();
    _sleepOnsetEpochMs = null;
    stateNotifier.value = RecorderState.idle;
  }

  void dispose() {
    _epochTimer?.cancel();
    _accelSub?.cancel();
    stateNotifier.dispose();
  }
}
