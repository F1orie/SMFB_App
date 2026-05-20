import 'sleep_epoch.dart';
import 'sleep_session.dart';

class SleepMetrics {
  const SleepMetrics({required this.totalSleepMin, required this.averageDepth});

  final int totalSleepMin;
  final double averageDepth;
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
      return SleepMetrics(totalSleepMin: totalSleepMin, averageDepth: 0);
    }

    final double totalDepth =
        epochs.map((e) => e.scoreDepth).reduce((a, b) => a + b);
    return SleepMetrics(
      totalSleepMin: totalSleepMin,
      averageDepth: totalDepth / epochs.length,
    );
  }
}
