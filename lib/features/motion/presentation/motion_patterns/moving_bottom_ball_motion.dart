import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 画面の下部を左右に移動し、中央で大きく、両端で小さくなるボールモーション。
///
/// - 周期: [period]（左端→右端の移動にかかる時間）
/// - サイズ: 中央で[maxDiameter]、左右の端で[minDiameter]
class MovingBottomBallMotion extends StatefulWidget {
  const MovingBottomBallMotion({
    super.key,
    this.period = const Duration(milliseconds: 6000), // 少し速くすると往復感がわかりやすいです
    this.minDiameter = 20,
    this.maxDiameter = 100,
    this.bottomPadding = 16,
    this.ballColor = const Color(0xFFFFB74D), // 明るいオレンジ
    this.glowColor = const Color(0xFFFFA726), // オレンジ
  });

  final Duration period;
  final double minDiameter;
  final double maxDiameter;
  final double bottomPadding;
  final Color ballColor;
  final Color glowColor;

  @override
  State<MovingBottomBallMotion> createState() => _MovingBottomBallMotionState();
}

class _MovingBottomBallMotionState extends State<MovingBottomBallMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant MovingBottomBallMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _ctrl.duration = widget.period;
      if (_ctrl.isAnimating) _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 左右の移動を滑らかにするためのカーブ
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;

        return AnimatedBuilder(
          animation: curved,
          builder: (context, _) {
            final t = curved.value; // 0.0(左端) 〜 1.0(右端) で往復

            // サイズの計算: サイン波を利用
            // t=0.0(左端) -> sin(0) = 0
            // t=0.5(中央) -> sin(π/2) = 1
            // t=1.0(右端) -> sin(π) = 0
            final sizeScale = math.sin(t * math.pi);
            final currentDiameter = widget.minDiameter +
                (widget.maxDiameter - widget.minDiameter) * sizeScale;

            // X軸：tの値に応じて左端から右端まで移動
            // ボールが画面外にはみ出ないように最大X座標を計算
            final maxX = math.max(0.0, w - currentDiameter);
            final x = maxX * t;
            
            // Y軸：画面の下部に配置（bottomPadding分だけ上にずらす）
            final y = math.max(0.0, h - currentDiameter - widget.bottomPadding);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: x.isFinite ? x : 0,
                  top: y.isFinite ? y : 0,
                  child: _Ball(
                    diameter: currentDiameter,
                    color: widget.ballColor,
                    glowColor: widget.glowColor,
                  ),
                ),
              ],
            );
          },
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