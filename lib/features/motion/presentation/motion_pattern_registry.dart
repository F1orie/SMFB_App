import 'package:flutter/material.dart';

import 'motion_patterns/pendulum_ball_motion.dart';
import 'motion_patterns/breathing_bottom_ball_motion.dart';
import 'motion_patterns/moving_bottom_ball_motion.dart';
import 'motion_patterns/tornado_motion.dart';
import 'motion_patterns/sleepy_breathing_balls_motion.dart';
import 'motion_patterns/rising_wave_ball_motion.dart';
import 'motion_patterns/wave_motion.dart';
import 'motion_patterns/rain_motion.dart';
import 'motion_patterns/flame_motion.dart';
import 'motion_patterns/snow_motion.dart';
import 'motion_patterns/ripple_motion.dart';
import 'motion_patterns/firefly_motion.dart';
import 'motion_patterns/jellyfish_motion.dart';
import 'motion_patterns/aurora_motion.dart';

// ═══════════════════════════════════════════════════════════════
//  【新しいモーションパターンの追加手順】
//
//  ① lib/features/motion/presentation/motion_patterns/
//     に新しいDartファイルを作成（Widgetを実装、colorパラメータ必須）
//
//  ② このファイルの上部に import を1行追加
//
//  ③ motionPatterns リストに MotionPatternDef を1件追加
//     （id・label・defaultColor・build・buildPreview を設定）
//
//  ── 以上！他のファイルは変更不要 ──
// ═══════════════════════════════════════════════════════════════

/// パターン1件の定義
class MotionPatternDef {
  const MotionPatternDef({
    required this.id,
    required this.label,
    required this.defaultColor,
    required this.build,
    required this.buildPreview,
  });

  final String id;
  final String label;
  final Color defaultColor;
  final Widget Function(Color color) build;
  final Widget Function(Color color) buildPreview;
}

/// ── パターン一覧 ──────────────────────────────────────────────
final List<MotionPatternDef> motionPatterns = [
  MotionPatternDef(
    id: 'pendulum',
    label: '振り子ボール',
    defaultColor: const Color(0xFFFFB74D),
    build: (c) => PendulumBallMotion(
      period: const Duration(milliseconds: 5000),
      ballColor: c, glowColor: c,
    ),
    buildPreview: (c) => PendulumBallMotion(
      period: const Duration(milliseconds: 5000),
      ballDiameter: 20, ballColor: c, glowColor: c,
    ),
  ),
  MotionPatternDef(
    id: 'breathing_bottom',
    label: '呼吸するボール',
    defaultColor: const Color(0xFFFFB74D),
    build: (c) => BreathingBottomBallMotion(ballColor: c, glowColor: c),
    buildPreview: (c) => BreathingBottomBallMotion(
      period: const Duration(milliseconds: 4000),
      minDiameter: 20, maxDiameter: 40, ballColor: c, glowColor: c,
    ),
  ),
  MotionPatternDef(
    id: 'moving_bottom',
    label: '浮遊ボール',
    defaultColor: const Color(0xFFFFB74D),
    build: (c) => MovingBottomBallMotion(ballColor: c, glowColor: c),
    buildPreview: (c) => MovingBottomBallMotion(
      period: const Duration(milliseconds: 3000),
      minDiameter: 20, maxDiameter: 100, ballColor: c, glowColor: c,
    ),
  ),
  MotionPatternDef(
    id: 'tornado',
    label: '竜巻モーション',
    defaultColor: Colors.orange,
    build: (c) => TornadoTopViewMotion(lineColor: c),
    buildPreview: (c) => TornadoTopViewMotion(
      period: const Duration(milliseconds: 3000),
      minScale: 0.3, maxScale: 1.2, lineColor: c,
    ),
  ),
  MotionPatternDef(
    id: 'sleepy_breathing',
    label: 'おやすみ呼吸ボール',
    defaultColor: const Color(0xFFFFB74D),
    build: (c) => SleepyBreathingBallsMotion(ballColor: c, glowColor: c),
    buildPreview: (c) => SleepyBreathingBallsMotion(
      period: const Duration(milliseconds: 12000),
      maxDiameter: 80, ballColor: c, glowColor: c,
    ),
  ),
  MotionPatternDef(
    id: 'rising_wave',
    label: '上昇ウェーブ',
    defaultColor: const Color(0xFFFFB74D),
    build: (c) => RisingWaveBallMotion(ballColor: c, glowColor: c),
    buildPreview: (c) => RisingWaveBallMotion(
      period: const Duration(milliseconds: 6000),
      minDiameter: 20, maxDiameter: 50, ballColor: c, glowColor: c,
    ),
  ),
  MotionPatternDef(
    id: 'wave',
    label: '波',
    defaultColor: Colors.white,
    build: (c) => WaveMotion(color: c),
    buildPreview: (c) => WaveMotion(color: c),
  ),
  MotionPatternDef(
    id: 'rain',
    label: '雨',
    defaultColor: Colors.white,
    build: (c) => RainMotion(color: c),
    buildPreview: (c) => RainMotion(color: c),
  ),
  MotionPatternDef(
    id: 'flame',
    label: '炎',
    defaultColor: const Color(0xFFFF7A2F),
    build: (c) => FlameMotion(color: c),
    buildPreview: (c) => FlameMotion(color: c),
  ),
  MotionPatternDef(
    id: 'snow',
    label: '雪',
    defaultColor: Colors.white,
    build: (c) => SnowMotion(color: c),
    buildPreview: (c) => SnowMotion(color: c),
  ),
  MotionPatternDef(
    id: 'ripple',
    label: '波紋',
    defaultColor: const Color(0xFFFF9900),
    build: (c) => RippleMotion(color: c),
    buildPreview: (c) => RippleMotion(color: c),
  ),
  MotionPatternDef(
    id: 'firefly',
    label: '蛍',
    defaultColor: const Color(0xFFFFF3A3),
    build: (c) => FireflyMotion(color: c),
    buildPreview: (c) => FireflyMotion(color: c),
  ),
  MotionPatternDef(
    id: 'jellyfish',
    label: 'クラゲ',
    defaultColor: Colors.white,
    build: (c) => JellyfishMotion(color: c),
    buildPreview: (c) => JellyfishMotion(color: c),
  ),
  MotionPatternDef(
    id: 'aurora',
    label: 'オーロラ',
    defaultColor: const Color(0xFF9EEFCF),
    build: (c) => AuroraMotion(color: c),
    buildPreview: (c) => AuroraMotion(color: c),
  ),
];
