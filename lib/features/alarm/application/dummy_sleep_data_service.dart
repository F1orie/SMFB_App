import '../domain/depth_scoring.dart';
import '../domain/sleep_epoch.dart';
import '../domain/sleep_note.dart';
import '../domain/sleep_session.dart';
import '../infrastructure/sleep_repository.dart';

class DummySleepDataService {
  DummySleepDataService({SleepRepository? repository})
      : _repository = repository ?? SleepRepository.instance;

  final SleepRepository _repository;

  Future<String> generateAndSave({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();

    // 指定日の 00:00〜07:00 を睡眠区間とする
    final startDt = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endDt = DateTime(targetDate.year, targetDate.month, targetDate.day, 7);

    final int startAt = startDt.millisecondsSinceEpoch;
    final int endAt = endDt.millisecondsSinceEpoch;

    // 同一日付の既存データを上書きできるよう日付をIDに含める
    final dateKey =
        '${targetDate.year}'
        '${targetDate.month.toString().padLeft(2, '0')}'
        '${targetDate.day.toString().padLeft(2, '0')}';

    final SleepSession session = SleepSession(
      id: 'dummy_$dateKey',
      startAtEpochMs: startAt,
      endAtEpochMs: endAt,
      status: SleepSessionStatus.finished,
      algoVersion: DepthScoring.algoVersion,
      samplingPeriodSec: 60,
      tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      appVersion: '0.1.0',
      syncState: 'local_only',
    );

    final List<SleepEpoch> epochs = _createDummyEpochs(
      sessionId: session.id,
      startAtEpochMs: startAt,
      minutes: 7 * 60,
    );

    final SleepNote note = SleepNote(
      sessionId: session.id,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      memo: 'Demo用ダミーデータ。就寝前にスマホを使用。',
      hadAlcohol: true,
      hadCaffeine: false,
      didExercise: false,
    );

    await _repository.saveSession(session);
    await _repository.saveEpochs(epochs);
    await _repository.saveNote(note);

    return session.id;
  }

  List<SleepEpoch> _createDummyEpochs({
    required String sessionId,
    required int startAtEpochMs,
    required int minutes,
  }) {
    final List<SleepEpoch> epochs = [];

    for (int i = 0; i < minutes; i++) {
      final double activityCount = _dummyActivityCount(i);

      epochs.add(
        SleepEpoch(
          sessionId: sessionId,
          tEpochMs: startAtEpochMs + Duration(minutes: i).inMilliseconds,
          activityCount: activityCount,
          scoreDepth: DepthScoring.calculateScoreDepth(activityCount),
        ),
      );
    }

    return epochs;
  }

  double _dummyActivityCount(int minute) {
    // 0〜30分：入眠前で体動多め
    if (minute < 30) return 0.9;

    // 30〜90分：浅い睡眠
    if (minute < 90) return 0.5;

    // 90〜210分：深い睡眠
    if (minute < 210) return 0.2;

    // 210〜225分：中途覚醒
    if (minute < 225) return 0.85;

    // 225〜360分：再び睡眠
    if (minute < 360) return 0.25;

    // 起床前：浅くなる
    return 0.6;
  }
}
