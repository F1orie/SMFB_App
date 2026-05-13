// lib/features/fb/infrastructure/api/sleep_mock_data.dart

import 'dart:math';
import '../../domain/features/sleep_data.dart'; // domainの設計図をインポート

/// 値を0.0〜1.0の範囲に収める補助関数 [cite: 8]
double _clamp01(double v) {
  if (v < 0) return 0;
  if (v > 1) return 1;
  return v;
}

/// 標準的な1日分の睡眠ダミーデータを生成する [cite: 9]
DailySleepDepthMock buildMockDailySleepDepth() {
  const startHour = 0;
  const endHour = 7;
  const stepMinutes = 5;
  final totalMinutes = (endHour - startHour) * 60; // [cite: 10]
  final points = <SleepDepthPoint>[];

  for (var m = 0; m <= totalMinutes; m += stepMinutes) { // [cite: 11]
    final t = m / totalMinutes;
    // 数学的な波形で睡眠の深さをシミュレート [cite: 12]
    final base = 0.45 + 0.30 * sin(t * pi) + 0.18 * sin(t * pi * 4 + 0.8) - 0.08 * sin(t * pi * 7);
    final depth01 = _clamp01(base); // [cite: 13]

    points.add(SleepDepthPoint(minuteFromZero: m, depth01: depth01)); // [cite: 13]
  }

  return DailySleepDepthMock(
    rangeLabel: '4月21日（月） - 22日（火）', // [cite: 14]
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
      lightTimeLabel: '5時間20分', // [cite: 15]
    ),
    memo: '夜にカフェインを飲んだため、途中で2回目が覚めた。', // [cite: 15]
  );
}

// 同様にして buildNoSleepMock() や buildOversleepMock() もここに記述します。