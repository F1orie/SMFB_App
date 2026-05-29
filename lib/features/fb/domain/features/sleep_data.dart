// lib/features/fb/domain/features/sleep_data.dart

/// グラフの一点（睡眠の深さ）を表すデータ
class SleepDepthPoint {
  const SleepDepthPoint({required this.minuteFromZero, required this.depth01});

  final int minuteFromZero; // 基準時刻からの経過分 [cite: 2]
  final double depth01; // 0.0〜1.0 の睡眠の深さ [cite: 2]
}

/// 睡眠の統計情報を表すデータ
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

  final String bedtimeLabel; // 就寝時刻 [cite: 4]
  final String fallAsleepLabel; // 入眠時刻 [cite: 4]
  final String wakeUpLabel; // 起床時刻 [cite: 4]
  final String sleepDurationLabel; // 睡眠時間 [cite: 4]
  final String latencyLabel; // 入眠潜時 [cite: 4]
  final String awakeningCountLabel; // 中途覚醒回数 [cite: 4]
  final String awakeningTimeLabel; // 中途覚醒時間 [cite: 5]
  final String efficiencyLabel; // 睡眠効率 [cite: 5]
  final String deepTimeLabel; // 深い睡眠の時間 [cite: 5]
  final String lightTimeLabel; // 浅い睡眠の時間 [cite: 5]
}

/// 1日分の睡眠データ全体をまとめるデータ
class DailySleepDepthMock {
  const DailySleepDepthMock({
    required this.rangeLabel,
    required this.xTickStartHour,
    required this.xTickEndHour,
    required this.points,
    required this.summary,
    required this.memo,
  });

  final String rangeLabel; // 対象日付のラベル [cite: 7]
  final int xTickStartHour; // グラフ開始時 [cite: 7]
  final int xTickEndHour; // グラフ終了時 [cite: 7]
  final List<SleepDepthPoint> points; // 睡眠の深さの点リスト [cite: 7]
  final SleepSummaryMock summary; // 統計データ [cite: 7]
  final String memo; // ユーザーメモ [cite: 7]
}
