import 'package:flutter/foundation.dart';

import '../domain/depth_scoring.dart';
import '../domain/sleep_epoch.dart';
import '../domain/sleep_session.dart';
import '../infrastructure/sleep_repository.dart';

enum RecorderState { idle, recording }

class SleepRecordResult {
  const SleepRecordResult({
    required this.sessionId,
    required this.durationMs,
  });

  final String sessionId;
  final int durationMs;
}

/// 睡眠計測の開始・停止を管理するサービス（デモ用インメモリ実装）。
class SleepRecorderService {
  SleepRecorderService({SleepRepository? repository})
      : _repository = repository ?? SleepRepository.instance;

  final SleepRepository _repository;

  final ValueNotifier<RecorderState> stateNotifier =
      ValueNotifier(RecorderState.idle);

  int? _startAtMs;
  String? _currentSessionId;

  void start() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _startAtMs = now;
    _currentSessionId = 'session_$now';
    stateNotifier.value = RecorderState.recording;
  }

  /// 記録を停止してセッションを保存する。記録中でない場合は null を返す。
  SleepRecordResult? stop() {
    if (_startAtMs == null || _currentSessionId == null) {
      stateNotifier.value = RecorderState.idle;
      return null;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs = now - _startAtMs!;
    final totalMinutes = (durationMs / 60000).ceil();

    final session = SleepSession(
      id: _currentSessionId!,
      startAtEpochMs: _startAtMs!,
      endAtEpochMs: now,
      status: SleepSessionStatus.finished,
      algoVersion: DepthScoring.algoVersion,
      samplingPeriodSec: 60,
      tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      appVersion: '0.1.0',
      syncState: 'local_only',
    );

    final epochs = <SleepEpoch>[];
    for (var i = 0; i < totalMinutes; i++) {
      const activity = 0.3;
      epochs.add(
        SleepEpoch(
          sessionId: _currentSessionId!,
          tEpochMs: _startAtMs! + Duration(minutes: i).inMilliseconds,
          activityCount: activity,
          scoreDepth: DepthScoring.calculateScoreDepth(activity),
        ),
      );
    }

    _repository.saveSession(session);
    _repository.saveEpochs(epochs);

    final result = SleepRecordResult(
      sessionId: _currentSessionId!,
      durationMs: durationMs,
    );

    _startAtMs = null;
    _currentSessionId = null;
    stateNotifier.value = RecorderState.idle;

    return result;
  }

  void dispose() {
    stateNotifier.dispose();
  }
}
