import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 画面の下から約1/3の高さまで上昇しながら大きくなるボールモーション。
///
/// - 周期: [period]（下で最小 → 上で最大 → 下で最小）
/// - サイズ: [minDiameter] から [maxDiameter] の間で変化
/// - 上昇幅: 画面の高さの [riseRatio] 倍（デフォルトで約1/3）
class RisingWaveBallMotion extends StatefulWidget {
  const RisingWaveBallMotion({
    super.key,
    this.period = const Duration(milliseconds: 5000),
    this.minDiameter = 20,
    this.maxDiameter = 100,
    this.bottomPadding = 16, // 画面下部からの初期余白
    this.riseRatio = 0.33, // 画面の約1/3まで上昇
    this.ballColor = const Color(0xFFFFB74D), // 明るいオレンジ
    this.glowColor = const Color(0xFFFFA726), // オレンジ
  });

  final Duration period;
  final double minDiameter;
  final double maxDiameter;
  final double bottomPadding;
  final double riseRatio;
  final Color ballColor;
  final Color glowColor;

  @override
  State<RisingWaveBallMotion> createState() => _RisingWaveBallMotionState();
}

class _RisingWaveBallMotionState extends State<RisingWaveBallMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant RisingWaveBallMotion oldWidget) {
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

            // 1. サイズの計算（t=0で最小、t=1で最大）
            final currentDiameter = widget.minDiameter +
                (widget.maxDiameter - widget.minDiameter) * t;

            // 2. X軸：画面の中央に配置
            final x = (w - currentDiameter) / 2;
            
            // 3. Y軸：一番下にあるときの基本位置
            final startY = math.max(0.0, h - currentDiameter - widget.bottomPadding);
            
            // 4. 上昇距離の計算（画面の高さ × 上昇割合）
            final riseDistance = h * widget.riseRatio;

            // 5. 最終的なY座標（tに応じて基本位置から上にスライド）
            final y = startY - (riseDistance * t);

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