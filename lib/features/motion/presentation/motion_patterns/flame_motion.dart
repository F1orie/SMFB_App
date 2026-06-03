import 'dart:math';
import 'package:flutter/material.dart';

class FlameMotion extends StatefulWidget {
  const FlameMotion({
    super.key,
    this.color = const Color(0xFFFF7A2F),
  });

  final Color color;

  @override
  State<FlameMotion> createState() => _FlameMotionState();
}

class _FlameMotionState extends State<FlameMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          return CustomPaint(
            painter: _FlamePainter(_controller.value, widget.color),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter(this.progress, this.baseColor);

  final double progress;
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height * 0.76;

    _drawGlow(canvas, size, centerX, baseY);
    _drawEmbers(canvas, size, centerX, baseY);

    final midColor = Color.lerp(baseColor, Colors.yellow, 0.4)!;
    final tipColor = Color.lerp(baseColor, Colors.white, 0.6)!;

    _drawFlameLayer(canvas, centerX: centerX, baseY: baseY,
        width: size.width * 0.30, height: size.height * 0.42,
        phase: progress, color: baseColor.withValues(alpha: 0.62), blur: 10);
    _drawFlameLayer(canvas, centerX: centerX, baseY: baseY + 10,
        width: size.width * 0.22, height: size.height * 0.34,
        phase: progress + 0.28, color: midColor.withValues(alpha: 0.78), blur: 8);
    _drawFlameLayer(canvas, centerX: centerX, baseY: baseY + 22,
        width: size.width * 0.11, height: size.height * 0.22,
        phase: progress + 0.53, color: tipColor.withValues(alpha: 0.78), blur: 5);
  }

  void _drawGlow(Canvas canvas, Size size, double centerX, double baseY) {
    final glowRadius =
        size.shortestSide * (0.32 + sin(progress * 2 * pi) * 0.03);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          baseColor.withValues(alpha: 0.24),
          baseColor.withValues(alpha: 0.09),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(centerX, baseY - size.height * 0.18),
          radius: glowRadius,
        ),
      );

    canvas.drawCircle(
      Offset(centerX, baseY - size.height * 0.18),
      glowRadius,
      paint,
    );
  }

  void _drawEmbers(Canvas canvas, Size size, double centerX, double baseY) {
    final emberPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 30; i++) {
      final seed = i * 0.137;
      final p = (progress + seed) % 1.0;

      final rise = p * size.height * 0.42;
      final sway =
          sin((p * 2 * pi) + i) * size.width * 0.05 +
          sin((p * 5 * pi) + i) * size.width * 0.015;

      final x = centerX + sway + cos(i * 1.7) * size.width * 0.08;
      final y = baseY - rise - size.height * 0.05;

      final opacity = (1.0 - p).clamp(0.0, 1.0);
      final radius = 1.4 + (i % 4) * 0.6;

      emberPaint.color = baseColor.withValues(alpha: opacity * 0.55);
      canvas.drawCircle(Offset(x, y), radius, emberPaint);
    }
  }

  void _drawFlameLayer(
    Canvas canvas, {
    required double centerX,
    required double baseY,
    required double width,
    required double height,
    required double phase,
    required Color color,
    required double blur,
  }) {
    final sway =
        sin(phase * 2 * pi) * width * 0.20 +
        sin(phase * 4 * pi) * width * 0.08;

    final breathe =
        0.90 +
        sin(phase * 2 * pi + pi / 3) * 0.10 +
        sin(phase * 6 * pi) * 0.03;

    final top = Offset(
      centerX + sway,
      baseY - height * breathe,
    );

    final leftControl1 = Offset(
      centerX - width * 0.75 + sin(phase * 2 * pi + 1.1) * width * 0.13,
      baseY - height * 0.72,
    );

    final leftControl2 = Offset(
      centerX - width * 0.58 + sin(phase * 3 * pi + 2.0) * width * 0.12,
      baseY - height * 0.26,
    );

    final rightControl1 = Offset(
      centerX + width * 0.58 + sin(phase * 3 * pi + 2.8) * width * 0.12,
      baseY - height * 0.26,
    );

    final rightControl2 = Offset(
      centerX + width * 0.75 + sin(phase * 2 * pi + 3.4) * width * 0.13,
      baseY - height * 0.72,
    );

    final path = Path()
      ..moveTo(centerX, baseY)
      ..cubicTo(
        leftControl2.dx,
        leftControl2.dy,
        leftControl1.dx,
        leftControl1.dy,
        top.dx,
        top.dy,
      )
      ..cubicTo(
        rightControl2.dx,
        rightControl2.dy,
        rightControl1.dx,
        rightControl1.dy,
        centerX,
        baseY,
      )
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FlamePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.baseColor != baseColor;
  }
}