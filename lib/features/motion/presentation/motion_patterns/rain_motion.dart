import 'dart:math';
import 'package:flutter/material.dart';

class RainMotion extends StatefulWidget {
  const RainMotion({super.key});

  @override
  State<RainMotion> createState() => _RainMotionState();
}

class _RainMotionState extends State<RainMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final Random random = Random();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
          painter: _RainPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RainPainter extends CustomPainter {
  final double progress;

  _RainPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 2;

    for (int i = 0; i < 40; i++) {
      final x = (i * 25.0) % size.width;

      final y =
          ((progress * size.height * 1.5) + (i * 40)) %
          (size.height + 40);

      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + 15),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}