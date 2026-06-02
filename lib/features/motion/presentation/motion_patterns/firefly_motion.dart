import 'dart:math';
import 'package:flutter/material.dart';

class FireflyMotion extends StatefulWidget {
  const FireflyMotion({super.key});

  @override
  State<FireflyMotion> createState() => _FireflyMotionState();
}

class _FireflyMotionState extends State<FireflyMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
            painter: _FireflyPainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  const _FireflyPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 18; i++) {
      final seed = i * 0.091;
      final t = (progress + seed) % 1.0;

      final x = (size.width * (0.12 + ((i * 37) % 76) / 100)) +
          sin(t * 2 * pi + i) * 18;

      final y = (size.height * (0.18 + ((i * 23) % 68) / 100)) +
          cos(t * 2 * pi + i * 1.4) * 16;

      final blink = 0.35 + sin(t * 2 * pi) * 0.30;
      final opacity = blink.clamp(0.08, 0.65);
      final radius = 2.0 + (i % 3) * 1.2;

      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3A3).withValues(alpha:opacity),
            const Color(0xFFFFD36B).withValues(alpha:opacity * 0.35),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(x, y),
            radius: radius * 6,
          ),
        );

      canvas.drawCircle(Offset(x, y), radius * 6, glowPaint);

      final corePaint = Paint()
        ..color = const Color(0xFFFFF8C7).withValues(alpha:opacity);

      canvas.drawCircle(Offset(x, y), radius, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}