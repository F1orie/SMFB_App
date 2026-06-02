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
//     に新しいDartファイルを作成（Widgetを実装）
//
//  ② このファイルの上部に import を1行追加
//
//  ③ motionPatterns リストに MotionPatternDef を1件追加
//     （id・label・build・buildPreview を設定）
//
//  ── 以上！他のファイルは変更不要 ──
// ═══════════════════════════════════════════════════════════════

/// パターン1件の定義
class MotionPatternDef {
  const MotionPatternDef({
    required this.id,
    required this.label,
    required this.build,
    required this.buildPreview,
  });

  /// 一意なID（英小文字・アンダースコア推奨）
  final String id;

  /// モーション画面に表示するラベル
  final String label;

  /// フルサイズで動作するウィジェットを生成
  final Widget Function() build;

  /// カード内プレビュー用の小さいウィジェットを生成
  final Widget Function() buildPreview;
}

/// ── パターン一覧 ──────────────────────────────────────────────
final List<MotionPatternDef> motionPatterns = [
  MotionPatternDef(
    id: 'pendulum',
    label: '振り子ボール',
    build: () => const PendulumBallMotion(
      period: Duration(milliseconds: 5000),
    ),
    buildPreview: () => const PendulumBallMotion(
      period: Duration(milliseconds: 5000),
      ballDiameter: 20,
    ),
  ),
  MotionPatternDef(
    id: 'breathing_bottom',
    label: '呼吸するボール',
    build: () => const BreathingBottomBallMotion(),
    buildPreview: () => const BreathingBottomBallMotion(
      period: Duration(milliseconds: 4000),
      minDiameter: 20,
      maxDiameter: 40,
    ),
  ),
  MotionPatternDef(
    id: 'moving_bottom',
    label: '浮遊ボール',
    build: () => const MovingBottomBallMotion(),
    buildPreview: () => const MovingBottomBallMotion(
      period: Duration(milliseconds: 3000),
      minDiameter: 20,
      maxDiameter: 100,
    ),
  ),
  MotionPatternDef(
    id: 'tornado',
    label: '竜巻モーション',
    build: () => const TornadoTopViewMotion(),
    buildPreview: () => const TornadoTopViewMotion(
      period: Duration(milliseconds: 3000),
      minScale: 0.3,
      maxScale: 1.2,
    ),
  ),
  MotionPatternDef(
    id: 'sleepy_breathing',
    label: 'おやすみ呼吸ボール',
    build: () => const SleepyBreathingBallsMotion(),
    buildPreview: () => const SleepyBreathingBallsMotion(
      period: Duration(milliseconds: 12000),
      maxDiameter: 80,
    ),
  ),

  // ↓ 新しいパターンをここに追加
  MotionPatternDef(
    id: 'rising_wave',      
    label: '上昇ウェーブ',             
    build: () => const RisingWaveBallMotion(),
    buildPreview: () => const RisingWaveBallMotion(
      period: Duration(milliseconds: 6000),
      minDiameter: 20,
      maxDiameter: 50,
    ),
  ),
  MotionPatternDef(
    id: 'wave',
    label: '波',
    build: () => const WaveMotion(),
    buildPreview: () => const WaveMotion(),
  ),
  MotionPatternDef(
    id: 'rain',
    label: '雨',
    build: () => const RainMotion(),
    buildPreview: () => const RainMotion(),
  ),

  MotionPatternDef(
    id: 'flame',
    label: '炎',
    build: () => const FlameMotion(),
    buildPreview: () => const FlameMotion(),
  ),

  MotionPatternDef(
    id: 'snow',
    label: '雪',
    build: () => const SnowMotion(),
    buildPreview: () => const SnowMotion(),
  ),
  MotionPatternDef(
    id: 'ripple',
    label: '波紋',
    build: () => const RippleMotion(),
    buildPreview: () => const RippleMotion(),
  ),
  MotionPatternDef(
    id: 'firefly',
    label: '蛍',
    build: () => const FireflyMotion(),
    buildPreview: () => const FireflyMotion(),
  ),

  MotionPatternDef(
    id: 'jellyfish',
    label: 'クラゲ',
    build: () => const JellyfishMotion(),
    buildPreview: () => const JellyfishMotion(),
  ),

  MotionPatternDef(
    id: 'aurora',
    label: 'オーロラ',
    build: () => const AuroraMotion(),
    buildPreview: () => const AuroraMotion(),
  ),
    // ↓ 新しいパターンをここに追加
  // MotionPatternDef(
  //   id: 'your_pattern_id',      // 例: 'wave'
  //   label: '表示名',             // 例: '波'
  //   build: () => const YourPatternWidget(),
  //   buildPreview: () => const YourPatternWidget(size: 'small'),
  // ),
 ];