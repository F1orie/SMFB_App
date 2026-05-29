import 'dart:math' as math;
import 'package:flutter/material.dart';

// ==========================================
// 呼吸するボール
// ==========================================

/// 画面の下中央で大きくなったり小さくなったりする（明滅・呼吸）ボールモーション。
///
/// - 周期: [period]（小→大→小）
/// - サイズ: [minDiameter] から [maxDiameter] の間で変化
class BreathingBottomBallMotion extends StatefulWidget {
  const BreathingBottomBallMotion({
    super.key,
    this.period = const Duration(milliseconds: 5000),
    this.minDiameter = 20,
    this.maxDiameter = 100,
    this.bottomPadding = 16, // 画面下部からの余白
    this.ballColor = const Color(0xFFBFE6FF),
    this.glowColor = const Color(0xFF6EC6FF),
  });

  final Duration period;
  final double minDiameter;
  final double maxDiameter;
  final double bottomPadding;
  final Color ballColor;
  final Color glowColor;

  @override
  State<BreathingBottomBallMotion> createState() => _BreathingBottomBallMotionState();
}

class _BreathingBottomBallMotionState extends State<BreathingBottomBallMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant BreathingBottomBallMotion oldWidget) {
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
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;

        return AnimatedBuilder(
          animation: curved,
          builder: (context, _) {
            final t = curved.value; // 0..1（reverseで往復）

            // tの値に応じて現在の直径を計算
            final currentDiameter = widget.minDiameter + 
                (widget.maxDiameter - widget.minDiameter) * t;

            // X軸：画面の中央に配置
            final x = (w - currentDiameter) / 2;
            
            // Y軸：画面の下部に配置（bottomPadding分だけ上にずらす）
            final y = math.max(0.0, h - currentDiameter - widget.bottomPadding);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: x.isFinite ? x : 0,
                  top: y.isFinite ? y : 0,
                  child: _Ball(
                    diameter: currentDiameter, // 計算した現在のサイズを渡す
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