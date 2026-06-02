import 'dart:math';
import 'package:flutter/material.dart';

class JellyfishMotion extends StatefulWidget {
  const JellyfishMotion({super.key});

  @override
  State<JellyfishMotion> createState() => _JellyfishMotionState();
}

class _JellyfishMotionState extends State<JellyfishMotion>
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _JellyfishPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _JellyfishPainter extends CustomPainter {
  const _JellyfishPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final y =
        size.height * 0.5 +
        sin(progress * 2 * pi) * size.height * 0.08;

    final bodyPaint = Paint()
      ..color = Colors.white.withOpacity(0.18);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, y),
        width: 120,
        height: 80,
      ),
      bodyPaint,
    );

    final tentaclePaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 2;

    for (int i = -4; i <= 4; i++) {
      final startX = centerX + i * 12;

      final path = Path();
      path.moveTo(startX, y + 30);

      for (int j = 1; j <= 5; j++) {
        path.lineTo(
          startX + sin(progress * 2 * pi + j + i) * 8,
          y + 30 + j * 25,
        );
      }

      canvas.drawPath(path, tentaclePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _JellyfishPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}