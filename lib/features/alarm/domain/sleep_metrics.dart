import 'sleep_epoch.dart';
import 'sleep_session.dart';

class SleepMetrics {
  const SleepMetrics({
    required this.totalSleepMin,
    required this.averageDepth,
    this.sleepOnsetMs,
  });

  final int totalSleepMin;
  final double averageDepth;
  /// 入眠時刻（epochMs）。検出できなかった場合はnull。
  final int? sleepOnsetMs;

  /// 就寝開始から入眠までの潜時（分）。未検出はnull。
  int? get sleepOnsetLatencyMin {
    if (sleepOnsetMs == null) return null;
    return null; // セッション情報がないためCalculatorで計算
  }
}

class SleepMetricsCalculator {
  static SleepMetrics calculate({
    required SleepSession session,
    required List<SleepEpoch> epochs,
  }) {
    final int start = session.startAtEpochMs;
    final int end = session.endAtEpochMs ?? start;
    final int totalSleepMin = ((end - start) / 1000 / 60).floor();

    if (epochs.isEmpty) {
      return SleepMetrics(
        totalSleepMin: totalSleepMin,
        averageDepth: 0,
        sleepOnsetMs: session.sleepOnsetEpochMs,
      );
    }

    final double totalDepth =
        epochs.map((e) => e.scoreDepth).reduce((a, b) => a + b);

    return SleepMetrics(
      totalSleepMin: totalSleepMin,
      averageDepth: totalDepth / epochs.length,
      sleepOnsetMs: session.sleepOnsetEpochMs,
    );
  }

  /// 就寝開始から入眠までの潜時（分）
  static int? calcOnsetLatencyMin(SleepSession session) {
    final onset = session.sleepOnsetEpochMs;
    if (onset == null) return null;
    return ((onset - session.startAtEpochMs) / 1000 / 60).floor();
  }
}
