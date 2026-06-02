import 'package:flutter/material.dart';

class RippleMotion extends StatefulWidget {
  const RippleMotion({super.key});

  @override
  State<RippleMotion> createState() => _RippleMotionState();
}

class _RippleMotionState extends State<RippleMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
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
            painter: _RipplePainter(_controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 4; i++) {
      final p = (progress + i * 0.25) % 1.0;
      final radius = p * size.shortestSide * 0.42;
      final opacity = (1.0 - p) * 0.35;

      final paint = Paint()
  ..color = const Color.fromARGB(255, 255, 153, 0).withValues(alpha:opacity)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}