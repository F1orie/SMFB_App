import 'dart:math';

/// グラフ機能（睡眠記録閲覧）用のモックデータ。
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
  });

  final String rangeLabel;
  final int xTickStartHour;
  final int xTickEndHour;
  final List<SleepDepthPoint> points;
  final SleepSummaryMock summary;
  final String memo;
}

double _clamp01(double v) {
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

/// 1日分の睡眠グラフ用モックデータ
DailySleepDepthMock buildMockDailySleepDepth() {
  const startHour = 0;
  const endHour = 7;
  const stepMinutes = 5;

  final totalMinutes = (endHour - startHour) * 60;
  final points = <SleepDepthPoint>[];

  for (var m = 0; m <= totalMinutes; m += stepMinutes) {
    final t = m / totalMinutes;

    final base =
        0.45 +
        0.30 * sin(t * pi) +
        0.18 * sin(t * pi * 4 + 0.8) -
        0.08 * sin(t * pi * 7);

    final depth01 = _clamp01(base);

    points.add(
      SleepDepthPoint(
        minuteFromZero: m,
        depth01: depth01,
      ),
    );
  }

  return DailySleepDepthMock(
    rangeLabel: '4月21日（月） - 22日（火）',
    xTickStartHour: startHour,
    xTickEndHour: endHour,
    points: points,
    summary: const SleepSummaryMock(
      bedtimeLabel: '23:45',
      fallAsleepLabel: '0:10',
      wakeUpLabel: '7:05',
      sleepDurationLabel: '6時間55分',
      latencyLabel: '25分',
      awakeningCountLabel: '2回',
      awakeningTimeLabel: '18分',
      efficiencyLabel: '89%',
      deepTimeLabel: '1時間35分',
      lightTimeLabel: '5時間20分',
    ),
    memo: '夜にカフェインを飲んだため、途中で2回目が覚めた。',
  );
}

/// 寝ていない日のモックデータ
DailySleepDepthMock buildNoSleepMock() {
  return const DailySleepDepthMock(
    rangeLabel: '4月22日（火） - 23日（水）',
    xTickStartHour: 0,
    xTickEndHour: 7,
    points: [
      SleepDepthPoint(minuteFromZero: 0, depth01: 0.02),
      SleepDepthPoint(minuteFromZero: 60, depth01: 0.01),
      SleepDepthPoint(minuteFromZero: 120, depth01: 0.02),
      SleepDepthPoint(minuteFromZero: 180, depth01: 0.01),
      SleepDepthPoint(minuteFromZero: 240, depth01: 0.02),
      SleepDepthPoint(minuteFromZero: 300, depth01: 0.01),
      SleepDepthPoint(minuteFromZero: 360, depth01: 0.02),
      SleepDepthPoint(minuteFromZero: 420, depth01: 0.01),
    ],
    summary: SleepSummaryMock(
      bedtimeLabel: '--:--',
      fallAsleepLabel: '--:--',
      wakeUpLabel: '--:--',
      sleepDurationLabel: '0時間',
      latencyLabel: '--',
      awakeningCountLabel: '0回',
      awakeningTimeLabel: '0分',
      efficiencyLabel: '0%',
      deepTimeLabel: '0分',
      lightTimeLabel: '0分',
    ),
    memo: '徹夜で課題したので寝ていない。',
  );
}

/// 昼過ぎまで寝た日のモックデータ
DailySleepDepthMock buildOversleepMock() {
  return const DailySleepDepthMock(
    rangeLabel: '4月23日（水） - 24日（木）',
    xTickStartHour: 0,
    xTickEndHour: 14,
    points: [
      SleepDepthPoint(minuteFromZero: 0, depth01: 0.20),
      SleepDepthPoint(minuteFromZero: 60, depth01: 0.55),
      SleepDepthPoint(minuteFromZero: 120, depth01: 0.85),
      SleepDepthPoint(minuteFromZero: 180, depth01: 0.60),
      SleepDepthPoint(minuteFromZero: 240, depth01: 0.90),
      SleepDepthPoint(minuteFromZero: 360, depth01: 0.65),
      SleepDepthPoint(minuteFromZero: 480, depth01: 0.75),
      SleepDepthPoint(minuteFromZero: 600, depth01: 0.45),
      SleepDepthPoint(minuteFromZero: 720, depth01: 0.30),
      SleepDepthPoint(minuteFromZero: 840, depth01: 0.10),
    ],
    summary: SleepSummaryMock(
      bedtimeLabel: '1:30',
      fallAsleepLabel: '2:00',
      wakeUpLabel: '13:45',
      sleepDurationLabel: '11時間45分',
      latencyLabel: '30分',
      awakeningCountLabel: '1回',
      awakeningTimeLabel: '12分',
      efficiencyLabel: '94%',
      deepTimeLabel: '3時間10分',
      lightTimeLabel: '8時間35分',
    ),
    memo: '休日だったので昼過ぎまで長く寝た。',
  );
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
