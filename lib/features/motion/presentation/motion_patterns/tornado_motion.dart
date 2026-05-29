import 'dart:math' as math;
import 'package:flutter/material.dart';

// ==========================================
// 竜巻モーション (WaveMotion)
// ==========================================

/// 画面中央の少し下で、上から見た竜巻（渦巻き）が回転しながら
/// 大きくなったり小さくなったりするモーション。
/// 複数の線が中心に向かって吸い込まれるように動きます。
class TornadoTopViewMotion extends StatefulWidget {
  const TornadoTopViewMotion({
    super.key,
    // 動きをゆっくりにするため、デフォルトの周期を6000ミリ秒に延長
    this.period = const Duration(milliseconds: 12000),
    this.minScale = 0.5,
    this.maxScale = 1.2,
    this.lineColor = const Color(0xFFBFE6FF),
  });

  final Duration period;
  final double minScale;
  final double maxScale;
  final Color lineColor;

  @override
  State<TornadoTopViewMotion> createState() => _TornadoTopViewMotionState();
}

class _TornadoTopViewMotionState extends State<TornadoTopViewMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void didUpdateWidget(covariant TornadoTopViewMotion oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0.0, 0.2),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;

          // 物理的なスケールの計算: サイン波を利用して往復
          final sizeScale = math.sin(t * math.pi);
          final currentScale = widget.minScale +
              (widget.maxScale - widget.minScale) * sizeScale;

          return Transform.scale(
            scale: currentScale,
            child: CustomPaint(
              size: const Size(160, 160),
              painter: _TopViewTornadoPainter(
                color: widget.lineColor,
                progress: t,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopViewTornadoPainter extends CustomPainter {
  _TopViewTornadoPainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // メインの線（色を薄くするため alpha を 0.5 に変更）
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 // 本数が増えるため少し細く
      ..strokeCap = StrokeCap.round;

    // ふわっと光らせるグロー効果（色を薄くするため alpha を 0.2 に変更）
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    // ★ 複数の線（腕）を設定
    const int numLines = 8; // 線の数を4から8に増加
    const double numCoils = 1.5; // 各線が何周するか
    const int pointsPerCoil = 60; // 1巻きあたりの滑らかさ
    final int totalPoints = (numCoils * pointsPerCoil).toInt();

    // アニメーションの進行度に基づく回転オフセット
    final rotationOffset = progress * 4 * math.pi;

    // 複数の線を描画するループ
    for (int j = 0; j < numLines; j++) {
      final path = Path();
      
      // 各線がスタートする角度を均等にずらす
      final double startAngleOffset = (j * 2 * math.pi) / numLines;

      for (int i = 0; i <= totalPoints; i++) {
        final double fraction = i / totalPoints;

        // 半径にカーブをかけることで、中心付近で線が密集し、吸い込み感を強調
        final double radiusFraction = math.pow(fraction, 1.3).toDouble();
        final double radius = maxRadius * radiusFraction;

        // 角度の計算: スタート位置 + 巻き具合 + 回転アニメーション
        final double angle = startAngleOffset + (fraction * numCoils * 2 * math.pi) + rotationOffset;

        final double x = center.dx + math.cos(angle) * radius;
        final double y = center.dy + math.sin(angle) * radius;

        if (i == 0) {
          path.moveTo(center.dx, center.dy);
        } else {
          path.lineTo(x, y);
        }
      }

      // 1本ずつグローとメイン線を描画
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TopViewTornadoPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}