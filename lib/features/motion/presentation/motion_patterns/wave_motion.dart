import 'dart:math';
import 'package:flutter/material.dart';

class WaveMotion extends StatefulWidget {
  const WaveMotion({super.key});

  @override
  State<WaveMotion> createState() => _WaveMotionState();
}

class _WaveMotionState extends State<WaveMotion>
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
            painter: _WavePainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final waveLine = Path();

    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.88 +
          sin(
                (x / size.width * 2 * pi) +
                    (progress * 2 * pi),
              ) *
              size.height *
              0.04;

      if (x == 0) {
        waveLine.moveTo(x, y);
      } else {
        waveLine.lineTo(x, y);
      }
    }

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha:0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(waveLine, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}