/// グラフ機能（睡眠記録閲覧）用のデータ型。
class SleepDepthPoint {
  const SleepDepthPoint({
    required this.minuteFromZero,
    required this.depth01,
  });

  /// グラフ基準からの経過分
  final int minuteFromZero;

  /// 0.0〜1.0 の睡眠の深さ
  /// 0に近いほど浅く、1に近いほど深い
  final double depth01;
}

class SleepSummaryMock {
  const SleepSummaryMock({
    required this.bedtimeLabel,
    required this.fallAsleepLabel,
    required this.wakeUpLabel,
    required this.sleepDurationLabel,
    required this.latencyLabel,
    required this.awakeningCountLabel,
    required this.awakeningTimeLabel,
    required this.efficiencyLabel,
    required this.deepTimeLabel,
    required this.lightTimeLabel,
  });

  final String bedtimeLabel;
  final String fallAsleepLabel;
  final String wakeUpLabel;
  final String sleepDurationLabel;
  final String latencyLabel;
  final String awakeningCountLabel;
  final String awakeningTimeLabel;
  final String efficiencyLabel;
  final String deepTimeLabel;
  final String lightTimeLabel;
}

class DailySleepDepthMock {
  const DailySleepDepthMock({
    required this.rangeLabel,
    required this.xTickStartHour,
    required this.xTickEndHour,
    required this.points,
    required this.summary,
    required this.memo,
    this.sessionId,
    this.alarmMinuteFromZero,
    this.actualWakeMinuteFromZero,
  });

  final String rangeLabel;
  final int xTickStartHour;
  final int xTickEndHour;
  final List<SleepDepthPoint> points;
  final SleepSummaryMock summary;
  final String memo;
  final String? sessionId;
  /// 設定起床時刻（グラフ開始からの経過分）
  final int? alarmMinuteFromZero;
  /// 実際のSTOP時刻（グラフ開始からの経過分）
  final int? actualWakeMinuteFromZero;
}

/// データが存在しない日のモック
DailySleepDepthMock buildEmptyMock(DateTime date) {
  return DailySleepDepthMock(
    rangeLabel: '${date.month}月${date.day}日',
    xTickStartHour: 0,
    xTickEndHour: 24,
    points: const [],
    summary: const SleepSummaryMock(
      bedtimeLabel: '--',
      fallAsleepLabel: '--',
      wakeUpLabel: '--',
      sleepDurationLabel: 'データなし',
      latencyLabel: '--',
      awakeningCountLabel: '--',
      awakeningTimeLabel: '--',
      efficiencyLabel: '--',
      deepTimeLabel: '--',
      lightTimeLabel: '--',
    ),
    memo: '',
  );
}
