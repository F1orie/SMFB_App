import 'dart:math';

import '../domain/depth_scoring.dart';
import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';
import '../infrastructure/sleep_repository.dart';

class DummySleepDataService {
  DummySleepDataService({SleepRepository? repository})
    : _repository = repository ?? SleepRepository.instance;

  final SleepRepository _repository;
  final Random _rng = Random();

  Future<String> generateAndSave({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();

    const int stepMinutes = 5;
    final int totalMinutes = 465 + _rng.nextInt(61); // 7時間45分〜8時間45分
    const int onsetLatencyMinutes = 15;
    final startDt = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endDt = startDt.add(Duration(minutes: totalMinutes));

    final int startAt = startDt.millisecondsSinceEpoch;
    final int endAt = endDt.millisecondsSinceEpoch;
    final int sleepOnsetAt = startDt
        .add(const Duration(minutes: onsetLatencyMinutes))
        .millisecondsSinceEpoch;

    final dateKey =
        '${targetDate.year}'
        '${targetDate.month.toString().padLeft(2, '0')}'
        '${targetDate.day.toString().padLeft(2, '0')}';

    final SleepSession session = SleepSession(
      id: 'dummy_$dateKey',
      startAtEpochMs: startAt,
      endAtEpochMs: endAt,
      sleepOnsetEpochMs: sleepOnsetAt,
      status: SleepSessionStatus.finished,
      algoVersion: DepthScoring.algoVersion,
      samplingPeriodSec: stepMinutes * 60,
      tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      appVersion: '0.1.0',
      syncState: 'local_only',
    );

    await _repository.saveSession(session);
    await _repository.removeEpochsForSession(session.id);

    final List<SleepEpoch> epochs = _createWaveEpochs(
      sessionId: session.id,
      startAtEpochMs: startAt,
      totalMinutes: totalMinutes,
      stepMinutes: stepMinutes,
      onsetLatencyMinutes: onsetLatencyMinutes,
    );

    final SleepNote note = SleepNote(
      sessionId: session.id,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      memo: 'Demo用ダミーデータ（睡眠時間は十分だが体動が多く浅い睡眠）',
      hadAlcohol: false,
      hadCaffeine: true,
      didExercise: false,
    );

    await _repository.saveEpochs(epochs);
    await _repository.saveNote(note);

    return session.id;
  }

  List<SleepEpoch> _createWaveEpochs({
    required String sessionId,
    required int startAtEpochMs,
    required int totalMinutes,
    required int stepMinutes,
    required int onsetLatencyMinutes,
  }) {
    final List<SleepEpoch> epochs = [];

    for (int m = 0; m <= totalMinutes; m += stepMinutes) {
      final double activityCount = _activityCountForMinute(
        minute: m,
        totalMinutes: totalMinutes,
        onsetLatencyMinutes: onsetLatencyMinutes,
      );
      final double scoreDepth = DepthScoring.calculateScoreDepth(activityCount);

      epochs.add(
        SleepEpoch(
          sessionId: sessionId,
          tEpochMs: startAtEpochMs + Duration(minutes: m).inMilliseconds,
          activityCount: activityCount,
          scoreDepth: scoreDepth,
        ),
      );
    }

    return epochs;
  }

  double _activityCountForMinute({
    required int minute,
    required int totalMinutes,
    required int onsetLatencyMinutes,
  }) {
    if (minute < onsetLatencyMinutes) {
      return _jitter(0.68, 0.08); // 就寝直後はまだ動きがある
    }

    if (minute < onsetLatencyMinutes + 15) {
      return _jitter(0.16, 0.03); // 入眠判定を成立させるための静かな区間
    }

    final int minutesAfterOnset = minute - onsetLatencyMinutes;
    final double nightProgress = minute / totalMinutes;
    final bool restlessBurst =
        minutesAfterOnset % 90 < 15 || minutesAfterOnset % 135 >= 120;

    if (restlessBurst) {
      return _jitter(0.86, 0.07); // 断続的な体動・中途覚醒寄り
    }

    if (nightProgress > 0.30 &&
        nightProgress < 0.45 &&
        minutesAfterOnset % 30 < 10) {
      return _jitter(0.32, 0.08); // 短い回復的な深睡眠
    }

    return _jitter(0.62, 0.08); // 時間は眠っているが浅い状態が中心
  }

  double _jitter(double center, double radius) {
    final value = center + (_rng.nextDouble() * 2 - 1) * radius;
    return value.clamp(0.0, 1.0);
  }
}
