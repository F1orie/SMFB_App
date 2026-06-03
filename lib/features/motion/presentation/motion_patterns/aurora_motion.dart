import 'dart:math';
import 'package:flutter/material.dart';

class AuroraMotion extends StatefulWidget {
  const AuroraMotion({
    super.key,
    this.color = const Color(0xFF9EEFCF),
  });

  final Color color;

  @override
  State<AuroraMotion> createState() => _AuroraMotionState();
}

class _AuroraMotionState extends State<AuroraMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
            painter: _AuroraPainter(_controller.value, widget.color),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // メインカラーからバリエーションを生成
    final hslColor = HSLColor.fromColor(color);
    final color2 = hslColor.withHue((hslColor.hue + 40) % 360).toColor();
    final color3 = hslColor.withHue((hslColor.hue + 80) % 360).toColor();

    _drawAuroraBand(canvas, size,
        baseY: size.height * 0.30, amplitude: size.height * 0.055,
        phase: progress, color: color, opacity: 0.18, strokeWidth: 42);
    _drawAuroraBand(canvas, size,
        baseY: size.height * 0.38, amplitude: size.height * 0.045,
        phase: progress + 0.35, color: color2, opacity: 0.14, strokeWidth: 36);
    _drawAuroraBand(canvas, size,
        baseY: size.height * 0.46, amplitude: size.height * 0.035,
        phase: progress + 0.68, color: color3, opacity: 0.11, strokeWidth: 28);
  }

  void _drawAuroraBand(Canvas canvas, Size size, {
    required double baseY, required double amplitude, required double phase,
    required Color color, required double opacity, required double strokeWidth,
  }) {
    final path = Path();
    for (double x = -20; x <= size.width + 20; x++) {
      final wave1 = sin((x / size.width * 2 * pi) + phase * 2 * pi);
      final wave2 = sin((x / size.width * 4 * pi) + phase * 2 * pi + 1.4);
      final y = baseY + wave1 * amplitude + wave2 * amplitude * 0.35;
      if (x == -20) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
