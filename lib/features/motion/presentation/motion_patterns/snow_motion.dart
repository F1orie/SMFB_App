import 'dart:math';
import 'package:flutter/material.dart';

class SnowMotion extends StatefulWidget {
  const SnowMotion({
    super.key,
    this.color = Colors.white,
  });

  final Color color;

  @override
  State<SnowMotion> createState() => _SnowMotionState();
}

class _SnowMotionState extends State<SnowMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
            painter: _SnowPainter(_controller.value, widget.color),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _SnowPainter extends CustomPainter {
  const _SnowPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 45; i++) {
      final seed = i * 0.173;
      final p = (progress + seed) % 1.0;
      final xBase = (i * 37.0) % size.width;
      final sway = sin((p * 2 * pi) + i) * 18;
      final x = xBase + sway;
      final y = (p * (size.height + 40)) - 20;
      final radius = 1.5 + (i % 4) * 0.8;
      final opacity = 0.25 + (i % 5) * 0.08;
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
