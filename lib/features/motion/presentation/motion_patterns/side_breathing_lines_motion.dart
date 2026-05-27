import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 画面両端から「ほわん」とした半円の光が中央に向かって膨らみ、
/// 中央に近づくにつれて透明に消えていく柔らかい呼吸モーション。
/// （※他のファイルでエラーが出ないよう、クラス名は SideBreathingLinesMotion のままにしています）
class SideBreathingLinesMotion extends StatefulWidget {
  const SideBreathingLinesMotion({
    super.key,
    this.period = const Duration(milliseconds: 6000), // ゆったりとした呼吸のペース
    this.color = const Color(0xFF81D4FA), // 柔らかくリラックスできる水色
  });

  final Duration period;
  final Color color;

  @override
  State<SideBreathingLinesMotion> createState() => _SideBreathingLinesMotionState();
}

class _SideBreathingLinesMotionState extends State<SideBreathingLinesMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period);
    // 吸って・吐いてを繰り返す
    _ctrl.repeat(reverse: true);
    // 緩やかな「ほわん」とした動きを表現
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
            // 0.0(縮んでいる) 〜 1.0(広がっている) の値を滑らかに往復
            final wave = _animation.value;

            // ★光のドーム（円）の直径を計算
            // 画面の高さや幅に合わせて、十分に大きく膨らむように設定
            final minDiameter = h * 0.5; // 最小のときでも少し見えている状態
            final maxDiameter = math.max(w, h) * 0.8; // 最大時は画面中央まで届く大きさ
            
            // 呼吸に合わせて直径を伸縮させる
            final diameter = minDiameter + (maxDiameter - minDiameter) * wave;

            // ★広がりきった時に、光全体を少しだけ薄くして「消えゆく感」を強調
            final opacity = (1.0 - wave * 0.3).clamp(0.3, 1.0);

            return IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // --- 左側の半円 ---
                  // 画面の左端から「円の半径分」だけ外側にズラして配置することで、
                  // 画面内には見事に「右半円」だけが現れます。
                  Positioned(
                    left: -diameter / 2,
                    top: (h / 2) - (diameter / 2),
                    child: Opacity(
                      opacity: opacity,
                      child: _SoftOrb(diameter: diameter, color: widget.color),
                    ),
                  ),

                  // --- 右側の半円 ---
                  // 同様に、画面の右端から外側へズラして配置（左半円が現れる）
                  Positioned(
                    right: -diameter / 2,
                    top: (h / 2) - (diameter / 2),
                    child: Opacity(
                      opacity: opacity,
                      child: _SoftOrb(diameter: diameter, color: widget.color),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 境界線を持たない、中心から外側へ向かって完全に透明に溶け込む光の球体
class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.diameter, required this.color});
  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // 円の中心（画面端）は色が濃く、外側（画面中央）に行くにつれて完全に透明になる
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.8), // 画面端はしっかり光る
            color.withValues(alpha: 0.3), // 中間エリア
            color.withValues(alpha: 0.0), // 画面中央へ向かって綺麗に消える！
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}