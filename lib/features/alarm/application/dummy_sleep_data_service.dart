import 'dart:math';

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

    final int sleepHours = 5 + _rng.nextInt(6); // 5〜10時間
    final startDt = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endDt = startDt.add(Duration(hours: sleepHours));

    final int startAt = startDt.millisecondsSinceEpoch;
    final int endAt = endDt.millisecondsSinceEpoch;

    final dateKey =
        '${targetDate.year}'
        '${targetDate.month.toString().padLeft(2, '0')}'
        '${targetDate.day.toString().padLeft(2, '0')}';

    final SleepSession session = SleepSession(
      id: 'dummy_$dateKey',
      startAtEpochMs: startAt,
      endAtEpochMs: endAt,
      status: SleepSessionStatus.finished,
      algoVersion: 'wave_v1',
      samplingPeriodSec: 60 * 5,
      tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      appVersion: '0.1.0',
      syncState: 'local_only',
    );

    await _repository.saveSession(session);
    await _repository.removeEpochsForSession(session.id);

    final List<SleepEpoch> epochs = _createWaveEpochs(
      sessionId: session.id,
      startAtEpochMs: startAt,
      totalMinutes: sleepHours * 60,
    );

    final SleepNote note = SleepNote(
      sessionId: session.id,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      memo: 'Demo用ダミーデータ（サイン波生成）',
      hadAlcohol: _rng.nextBool(),
      hadCaffeine: _rng.nextBool(),
      didExercise: _rng.nextBool(),
    );

    await _repository.saveEpochs(epochs);
    await _repository.saveNote(note);

    return session.id;
  }

  List<SleepEpoch> _createWaveEpochs({
    required String sessionId,
    required int startAtEpochMs,
    required int totalMinutes,
  }) {
    final double baseOffset = 0.40 + _rng.nextDouble() * 0.10;
    final double amp1 = 0.25 + _rng.nextDouble() * 0.10;
    final double amp2 = 0.10 + _rng.nextDouble() * 0.15;
    final double amp3 = 0.05 + _rng.nextDouble() * 0.08;
    final double freq2 = 3.0 + _rng.nextDouble() * 2.0;
    final double phase2 = _rng.nextDouble() * 2 * pi;
    final double phase3 = _rng.nextDouble() * 2 * pi;

    const stepMinutes = 5;
    final List<SleepEpoch> epochs = [];

    for (int m = 0; m <= totalMinutes; m += stepMinutes) {
      final double t = m / totalMinutes;
      final double raw =
          baseOffset +
          amp1 * sin(t * pi) +
          amp2 * sin(t * pi * freq2 + phase2) -
          amp3 * sin(t * pi * 7 + phase3);
      final double depth01 = raw.clamp(0.0, 1.0);

      epochs.add(
        SleepEpoch(
          sessionId: sessionId,
          tEpochMs: startAtEpochMs + Duration(minutes: m).inMilliseconds,
          activityCount: 1.0 - depth01,
          scoreDepth: depth01,
        ),
      );
    }

    return epochs;
  }
}
