import 'dart:math';

/// グラフ機能（睡眠記録閲覧）用のダミーデータ。
///
/// ユーザー要望に従い、`lib/features/graph/` の直下に置きます。
/// （Android で実測したデータ連携は未実装。UI 表現のための固定モックのみ。）
class SleepDepthPoint {
  const SleepDepthPoint({required this.minuteFromZero, required this.depth01});

  /// グラフ基準（例: 0時）からの経過分
  final int minuteFromZero;

  /// 0.0〜1.0 の正規化深さ（深いほど 1.0）
  final double depth01;
}

class SleepSummaryMock {
  const SleepSummaryMock({
    required this.bedtimeLabel, // 就寝時刻
    required this.fallAsleepLabel, // 入眠時刻
    required this.wakeUpLabel, // 起床時刻
    required this.sleepDurationLabel, // 睡眠時間
    required this.latencyLabel, // 入眠潜時（任意）
    required this.awakeningCountLabel, // 中途覚醒回数
    required this.awakeningTimeLabel, // 覚醒時間（任意）
    required this.efficiencyLabel, // 睡眠効率
    required this.deepTimeLabel, // 深睡眠時間（任意）
    required this.lightTimeLabel, // 浅睡眠時間（任意）
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
  });

  /// 例：「8月9日（木） - 10日（金）」
  final String rangeLabel;

  /// x 軸（時刻）表示の範囲
  final int xTickStartHour;
  final int xTickEndHour;

  /// 1日分の深さ推移（例：0〜7時を 5分刻み）
  final List<SleepDepthPoint> points;

  /// 下部「データ」タブの表示用集計モック
  final SleepSummaryMock summary;
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// スクリーンショットに近い雰囲気の曲線を作る固定モック。
DailySleepDepthMock buildMockDailySleepDepth() {
  const startHour = 0;
  const endHour = 7;
  const stepMinutes = 5;

  final totalMinutes = (endHour - startHour) * 60;
  final points = <SleepDepthPoint>[];

  for (var m = 0; m <= totalMinutes; m += stepMinutes) {
    final t = m / totalMinutes; // 0..1

    // 浅→深→浅→深→浅のように「それっぽい遷移」になる波形を簡単に合成
    final base =
        0.55 +
        0.35 * sin(t * pi) +
        0.10 * sin(t * pi * 2 + 0.7) -
        0.08 * sin(t * pi * 3 + 1.4);

    final wobble = 0.02 * sin(m / 18.0);
    final depth01 = _clamp01(base + wobble);

    points.add(SleepDepthPoint(minuteFromZero: m, depth01: depth01));
  }

  return DailySleepDepthMock(
    rangeLabel: '8月9日（木） - 10日（金）',
    xTickStartHour: startHour,
    xTickEndHour: endHour,
    points: points,
    summary: const SleepSummaryMock(
      bedtimeLabel: '23:58',
      fallAsleepLabel: '0:09',
      wakeUpLabel: '7:03',
      sleepDurationLabel: '7時間5分12秒',
      latencyLabel: '0分5秒',
      awakeningCountLabel: '0回',
      awakeningTimeLabel: '0秒',
      efficiencyLabel: '96.7%',
      deepTimeLabel: '約60分',
      lightTimeLabel: '約240分',
    ),
  );
}
