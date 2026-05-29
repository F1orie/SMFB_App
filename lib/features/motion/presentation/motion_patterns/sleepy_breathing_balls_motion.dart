import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ボールの配置場所と、アニメーションが始まるタイミングのズレ（phase）を定義するクラス
class BallData {
  final Alignment alignment;
  final double phase; // 0.0 ~ 1.0 の間で、アニメーションの開始をどれくらい遅らせるか

  BallData({required this.alignment, required this.phase});
}

/// 1つが現れて消えた後、違う場所からもう1つが現れるボールモーション（深呼吸スピード版）
class SleepyBreathingBallsMotion extends StatefulWidget {
  const SleepyBreathingBallsMotion({
    super.key,
    // 【変更点】全体の時間を64秒に延長。
    // 1つあたりのボールが約7.6秒（吸って吐いての深呼吸ペース）かけてゆっくり明滅します。
    this.period = const Duration(milliseconds: 64000), 
    this.maxDiameter = 120, // 最大サイズ
    this.ballColor = const Color(0xFFBFE6FF),
    this.glowColor = const Color(0xFF6EC6FF),
  });

  final Duration period;
  final double maxDiameter;
  final Color ballColor;
  final Color glowColor;

  @override
  State<SleepyBreathingBallsMotion> createState() =>
      _SleepyBreathingBallsMotionState();
}

class _SleepyBreathingBallsMotionState
    extends State<SleepyBreathingBallsMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 8つのボールの配置と、開始タイミングのズレ（1/8ずつズラして1つずつ順番に出現させる）
  final List<BallData> _balls = [
    BallData(alignment: const Alignment(-0.7, -0.6), phase: 0.0),
    BallData(alignment: const Alignment(0.5, -0.8), phase: 0.125),
    BallData(alignment: const Alignment(-0.3, -0.1), phase: 0.25),
    BallData(alignment: const Alignment(0.8, -0.2), phase: 0.375),
    BallData(alignment: const Alignment(-0.8, 0.4), phase: 0.5),
    BallData(alignment: const Alignment(0.4, 0.5), phase: 0.625),
    BallData(alignment: const Alignment(-0.4, 0.8), phase: 0.75),
    BallData(alignment: const Alignment(0.7, 0.7), phase: 0.875),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.period,
    )..repeat(); // reverseさせず、0.0 -> 1.0 を繰り返す
  }

  @override
  void didUpdateWidget(covariant SleepyBreathingBallsMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _ctrl.duration = widget.period;
      if (_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// ボールの現在のサイズを計算する関数
  double _calculateDiameter(double t, double phase) {
    // 自身の開始タイミング(phase)に合わせて時間を引くことで、リスト順に表示されるようにする
    final double localT = (t - phase + 1.0) % 1.0;

    // 8個が重ならない最大値は0.125(1/8)。
    // 0.12に設定することで、ボールが消えた後にほんの一瞬だけ「間」を作り、次のボールを出します。
    const double breathPortion = 0.12;

    if (localT < breathPortion) {
      // 呼吸期間中の進行度 (0.0 ~ 1.0)
      final double normalizedT = localT / breathPortion;
      // サインカーブ（sin）を使って、滑らかに 0 → 1 → 0 と変化させる
      final double curve = math.sin(normalizedT * math.pi);
      return curve * widget.maxDiameter;
    } else {
      // お休み期間は見えない状態（サイズ0）
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value; // 0.0 ~ 1.0 を繰り返す

        return Stack(
          fit: StackFit.expand,
          children: _balls.map((ball) {
            // 各ボールの現在のサイズを計算
            final currentDiameter = _calculateDiameter(t, ball.phase);

            return Align(
              alignment: ball.alignment,
              child: _Ball(
                // サイズが0以下の時は描画負荷を下げるために非表示にする
                diameter: math.max(0.0, currentDiameter),
                color: widget.ballColor,
                glowColor: widget.glowColor,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Ball extends StatelessWidget {
  const _Ball({
    required this.diameter,
    required this.color,
    required this.glowColor,
  });

  final double diameter;
  final Color color;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    // サイズが完全に0の時は何も描画しない
    if (diameter <= 0) return const SizedBox.shrink();

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.96),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}