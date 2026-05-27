import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:smf_app/features/motion/application/motion_state.dart';
import 'breathing_pendulum_motion.dart';

/// 振り子のように左右へゆったり往復する球体モーション。
class PendulumBallMotion extends StatefulWidget {
  const PendulumBallMotion({
    super.key,
    this.period = const Duration(milliseconds: 5000),
    this.ballDiameter = 26,
    this.ballColor = const Color(0xFFBFE6FF),
    this.glowColor = const Color(0xFF6EC6FF),
    this.maxAngleRad = 0.95,
    this.isPreview = false, // カード内のプレビュー表示の時は強制的に振り子を出すためのフラグ
  });

  final Duration period;
  final double ballDiameter;
  final Color ballColor;
  final Color glowColor;
  final double maxAngleRad;
  final bool isPreview; 

  @override
  State<PendulumBallMotion> createState() => _PendulumBallMotionState(); // ★ここと
}

// ★ここの名前を「_PendulumBallMotionState」に綺麗に統一してエラーを修正しました！
class _PendulumBallMotionState extends State<PendulumBallMotion> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant PendulumBallMotion oldWidget) {
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
    // プレビュー中ではなく、かつ全体状態で固定点（breathing）が選ばれている場合
    // main.dartからこのクラスが呼ばれた瞬間に、中身を固定点明滅モーションへすり替えて表示する
    if (!widget.isPreview) {
      return ValueListenableBuilder<String>(
        valueListenable: MotionState.selectedPattern,
        builder: (context, pattern, _) {
          if (pattern == 'breathing') {
            return BreathingPendulumMotion(
              period: widget.period,
              ballDiameter: widget.ballDiameter,
              dotColor: widget.ballColor,
              glowColor: widget.glowColor,
            );
          }
          return _buildOriginalPendulum(); // 通常は振り子を出す
        },
      );
    }

    return _buildOriginalPendulum();
  }

  // 元々の振り子ボールの描画処理
  Widget _buildOriginalPendulum() {
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        final diameter = widget.ballDiameter.clamp(6.0, 200.0).toDouble();

        return AnimatedBuilder(
          animation: curved,
          builder: (context, _) {
            final t = curved.value;
            final maxAngle = widget.maxAngleRad.clamp(0.2, 1.25);
            final theta = (t * 2 - 1) * maxAngle;

            final maxX = math.max(0.0, (w - diameter) * 0.45);
            final maxY = math.max(0.0, (h - diameter) * 0.55);
            final lx = (maxX > 0) ? maxX / math.max(0.001, math.sin(maxAngle)) : 0.0;
            final ly = (maxY > 0) ? maxY / math.max(0.001, (1 - math.cos(maxAngle))) : 0.0;
            final l = math.max(0.0, math.min(lx, ly));

            final pivotX = w / 2;
            final maxDrop = l * (1 - math.cos(maxAngle));
            var pivotY = h / 2 - maxDrop / 2;
            final minPivotY = diameter * 0.5;
            final maxPivotY = math.max(minPivotY, h - maxDrop - diameter * 0.5);
            pivotY = pivotY.clamp(minPivotY, maxPivotY);

            final cx = pivotX + l * math.sin(theta);
            final cy = pivotY + l * (1 - math.cos(theta));

            final x = cx - (diameter / 2);
            final y = cy - (diameter / 2);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: x.isFinite ? x : 0,
                  top: y.isFinite ? y : 0,
                  child: _Ball(
                    diameter: diameter,
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