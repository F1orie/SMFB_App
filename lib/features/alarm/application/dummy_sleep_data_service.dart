import 'dart:math';

import '../domain/depth_scoring.dart';
import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';
import '../infrastructure/sleep_repository.dart';

enum _SleepPattern { light, deep }

class DummySleepDataService {
  DummySleepDataService({SleepRepository? repository})
    : _repository = repository ?? SleepRepository.instance;

  final SleepRepository _repository;
  final Random _rng = Random();

  Future<String> generateAndSave({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();

    // ランダムでパターンを決定
    final pattern = _rng.nextBool() ? _SleepPattern.deep : _SleepPattern.light;

    const int stepMinutes = 5;
    final int totalMinutes = 450 + _rng.nextInt(60); // 7時間30分〜8時間30分
    final int onsetLatencyMinutes = pattern == _SleepPattern.deep
        ? 10 + _rng.nextInt(10)   // 深い睡眠: 入眠潜時 10〜19分
        : 15 + _rng.nextInt(15);  // 浅い睡眠: 入眠潜時 15〜29分

    final startDt = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endDt = startDt.add(Duration(minutes: totalMinutes));

    final int startAt = startDt.millisecondsSinceEpoch;
    final int endAt = endDt.millisecondsSinceEpoch;
    final int sleepOnsetAt = startDt
        .add(Duration(minutes: onsetLatencyMinutes))
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
      pattern: pattern,
    );

    final SleepNote note = _buildNote(session.id, pattern);

    await _repository.saveEpochs(epochs);
    await _repository.saveNote(note);

    return session.id;
  }

  SleepNote _buildNote(String sessionId, _SleepPattern pattern) {
    if (pattern == _SleepPattern.deep) {
      return SleepNote(
        sessionId: sessionId,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        memo: 'Demo用ダミーデータ（深い睡眠がしっかり取れた良質な睡眠）',
        hadAlcohol: false,
        hadCaffeine: false,
        didExercise: true,
      );
    }
    return SleepNote(
      sessionId: sessionId,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      memo: 'Demo用ダミーデータ（睡眠時間は十分だが体動が多く浅い睡眠）',
      hadAlcohol: false,
      hadCaffeine: true,
      didExercise: false,
    );
  }

  List<SleepEpoch> _createWaveEpochs({
    required String sessionId,
    required int startAtEpochMs,
    required int totalMinutes,
    required int stepMinutes,
    required int onsetLatencyMinutes,
    required _SleepPattern pattern,
  }) {
    final List<SleepEpoch> epochs = [];

    for (int m = 0; m <= totalMinutes; m += stepMinutes) {
      final double activityCount = pattern == _SleepPattern.deep
          ? _deepActivityCount(
              minute: m,
              totalMinutes: totalMinutes,
              onsetLatencyMinutes: onsetLatencyMinutes,
            )
          : _lightActivityCount(
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

  // ── 浅い睡眠パターン ─────────────────────────────────────────
  double _lightActivityCount({
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

  // ── 深い睡眠パターン ─────────────────────────────────────────
  // 90分周期の睡眠サイクルを模倣。前半に深睡眠が集中する正常なパターン。
  double _deepActivityCount({
    required int minute,
    required int totalMinutes,
    required int onsetLatencyMinutes,
  }) {
    if (minute < onsetLatencyMinutes) {
      return _jitter(0.55, 0.08); // 就寝直後（浅い睡眠パターンより落ち着いている）
    }

    if (minute < onsetLatencyMinutes + 10) {
      return _jitter(0.12, 0.03); // 入眠判定を確実に成立させる区間
    }

    final int minutesAfterOnset = minute - onsetLatencyMinutes;
    final double nightProgress = minute / totalMinutes;

    // 90分周期内の位置（0.0〜1.0）
    final int cycleMinute = minutesAfterOnset % 90;
    final double cyclePos = cycleMinute / 90.0;

    // サイクル境界（覚醒に近い浅い睡眠）
    if (cyclePos < 0.08 || cyclePos > 0.92) {
      return _jitter(0.45, 0.08);
    }

    // 前半の夜（深睡眠が多い）
    if (nightProgress < 0.50) {
      if (cyclePos >= 0.15 && cyclePos <= 0.55) {
        return _jitter(0.10, 0.04); // 深睡眠（ほぼ静止）
      }
      return _jitter(0.28, 0.06); // 浅めだが良質
    }

    // 後半の夜（レム睡眠・浅い睡眠が多くなる）
    if (cyclePos >= 0.25 && cyclePos <= 0.55) {
      return _jitter(0.22, 0.05); // やや深め
    }
    return _jitter(0.38, 0.07); // 浅めのレム睡眠寄り
  }

  double _jitter(double center, double radius) {
    final value = center + (_rng.nextDouble() * 2 - 1) * radius;
    return value.clamp(0.0, 1.0);
  }
}
