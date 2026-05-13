import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/depth_scoring.dart';
import '../domain/sleep_epoch.dart';
import '../domain/sleep_metrics.dart';
import '../domain/sleep_session.dart';

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

  final ValueNotifier<RecorderState> stateNotifier =
      ValueNotifier<RecorderState>(RecorderState.idle);

  SleepSession? _currentSession;
  final List<SleepEpoch> _epochs = [];
  Timer? _timer;

  SleepSession? get currentSession => _currentSession;
  List<SleepEpoch> get epochs => List.unmodifiable(_epochs);

  void start({int? alarmTimeEpochMs}) {
    if (stateNotifier.value == RecorderState.recording) return;

    final int now = DateTime.now().millisecondsSinceEpoch;

    _currentSession = SleepSession(
      id: 'session_$now',
      startAtEpochMs: now,
      alarmTimeEpochMs: alarmTimeEpochMs,
      status: SleepSessionStatus.recording,
      algoVersion: DepthScoring.algoVersion,
      samplingPeriodSec: 60,
      tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      appVersion: '0.1.0',
      syncState: 'local_only',
    );

    _epochs.clear();
    stateNotifier.value = RecorderState.recording;

    // 動作確認しやすいように5秒ごとに仮エポックを追加する
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _addMockEpoch();
    });
  }

  SleepRecordResult? stop() {
    if (stateNotifier.value != RecorderState.recording) return null;

    stateNotifier.value = RecorderState.finishing;
    _timer?.cancel();
    _timer = null;

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
    stateNotifier.value = RecorderState.idle;

    return SleepRecordResult(
      session: finishedSession,
      epochs: List.unmodifiable(_epochs),
      metrics: metrics,
    );
  }

  void abort() {
    _timer?.cancel();
    _timer = null;
    _currentSession = null;
    _epochs.clear();
    stateNotifier.value = RecorderState.idle;
  }

  void dispose() {
    _timer?.cancel();
    stateNotifier.dispose();
  }

  void _addMockEpoch() {
    final SleepSession? session = _currentSession;
    if (session == null) return;

    final double activityCount = _mockActivityCount(_epochs.length);

    _epochs.add(
      SleepEpoch(
        sessionId: session.id,
        tEpochMs: DateTime.now().millisecondsSinceEpoch,
        activityCount: activityCount,
        scoreDepth: DepthScoring.calculateScoreDepth(activityCount),
      ),
    );
  }

  double _mockActivityCount(int index) {
    if (index < 2) return 0.9;
    if (index < 4) return 0.5;
    if (index < 8) return 0.2;
    if (index == 8 || index == 9) return 0.8;
    return 0.1;
  }
}
