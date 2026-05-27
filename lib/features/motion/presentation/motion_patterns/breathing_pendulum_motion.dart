import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 左右の画面端に、縦1列（片側4個・計8個）のドットが固定配置され、
/// 呼吸リズム（サイン波）に合わせてその場で大小に伸縮・明滅するモーション。
class BreathingPendulumMotion extends StatefulWidget {
  const BreathingPendulumMotion({
    super.key,
    this.period = const Duration(milliseconds: 5000),
    this.ballDiameter = 24.0, // ★ 基準サイズを 16.0 から 24.0 に大きく変更！
    this.dotColor = const Color(0xFFBFE6FF),
    this.glowColor = const Color(0xFF6EC6FF),
  });

  final Duration period;
  final double ballDiameter;
  final Color dotColor;
  final Color glowColor;

  @override
  State<BreathingPendulumMotion> createState() => _BreathingPendulumMotionState();
}

class _BreathingPendulumMotionState extends State<BreathingPendulumMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period);
    _ctrl.repeat(reverse: true);
    
    // なめらかな往復（easeInOutSine）のアニメーション
    _animation = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final t = _animation.value; // 0.0 〜 1.0 を往復

            // 8個の固定ドットを格納するリスト
            final dots = <Widget>[];

            // 左右の画面端からの余白（横位置）
            const sidePadding = 24.0;

            // 画面全体の高さ（h）に応じて、ドットの上下間隔をダイナミックに広げる
            final verticalInterval = h > 200 ? h * 0.18 : 24.0;

            // 左右（isLeft）、行（row: 0〜3の4段）をループして合計8個を配置
            for (var isLeft in [true, false]) {
              for (var row = 0; row < 4; row++) {
                
                // 上下へ光が心地よく波打つための時間差（ディレイ）計算
                final delay = row * 0.15;
                final wave = math.sin((t * math.pi) + delay);
                
                // 各ドットの中心位置をロックしたまま、直径（diameter）だけを伸縮
                final scaleFactor = 1.0 + 0.8 * wave;
                final diameter = widget.ballDiameter * scaleFactor;

                // 縦位置（Y軸）：全体の高さを計算し、画面の中央を基準に縦長く配置
                final baseY = (h / 2) - ((3 * verticalInterval) / 2);
                final y = baseY + (row * verticalInterval) - (diameter / 2);

                // 横位置（X軸）：左右それぞれの画面端に固定
                final x = isLeft
                    ? sidePadding - (diameter / 2)
                    : w - sidePadding - (diameter / 2);

                dots.add(
                  Positioned(
                    left: x.isFinite ? x : 0,
                    top: y.isFinite ? y : 0,
                    child: _StaticBall(
                      diameter: diameter,
                      color: widget.dotColor,
                      glowColor: widget.glowColor,
                    ),
                  ),
                );
              }
            }

            return IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: dots,
              ),
            );
          },
        );
      },
    );
  }
}

/// 固定配置される光るドットの見た目
class _StaticBall extends StatelessWidget {
  const _StaticBall({
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
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.50),
            color.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            // ★ ボールが大きくなったのに合わせて、ネオンの光（ぼかし幅）も 16 から 22 へ少し広げてリッチにしています
            blurRadius: 22, 
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}