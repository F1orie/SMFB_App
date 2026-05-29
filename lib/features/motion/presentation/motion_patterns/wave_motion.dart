import 'dart:math' as math;
import 'package:flutter/material.dart';

// ==========================================
// 波モーション 
// ==========================================

/// 画面全体にゆっくりと流れる波を描画するリラックスモーション。
/// サイン波（sin）のロジックを使用し、時間をかけて横にスライドします。
class WaveMotion extends StatefulWidget {
  const WaveMotion({
    super.key,
    this.period = const Duration(seconds: 8), // ゆったりとした波の流れるペース
    this.color = const Color(0x593F51B5), // 落ち着いた色合い
    this.isPreview = false, // プレビュー画面かどうかを判定するフラグ
  });

  final Duration period;
  final Color color;
  final bool isPreview;

  @override
  State<WaveMotion> createState() => _WaveMotionState();
}

class _WaveMotionState extends State<WaveMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    // 指定した時間をかけて0.0から1.0まで進むコントローラー
    _ctrl = AnimationController(vsync: this, duration: widget.period);
    
    // 波は常に一方向に流れ続けるため、reverse: false（デフォルト）で繰り返す
    _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant WaveMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 周期（period）が外から変更された場合、コントローラーに反映させる
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 親ウィジェットのサイズを取得（無限大の場合は画面サイズを使用）
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            // 0.0 〜 1.0 の進行度
            final progress = _ctrl.value;

            return IgnorePointer(
              child: CustomPaint(
                size: Size(w, h),
                painter: _WavePainter(
                  progress: progress,
                  color: widget.color,
                  isPreview: widget.isPreview,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 実際にキャンバスに波（Path）を描画するクラス
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.color,
    required this.isPreview,
  });

  final double progress;
  final Color color;
  final bool isPreview;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    // 画面の中央（高さの半分）を波の基準線（ベース）とする
    final baseY = size.height / 2;

    // ★プレビュー表示（カード内）のときは波の振れ幅を少し控えめにする
    final waveAmplitude = isPreview ? 12.0 : 24.0;

    // 画面の左端(x=0)から右端(x=size.width)まで線を結んでいく
    for (double x = 0; x <= size.width; x++) {
      // x / size.width * 2 * pi : 画面幅でちょうど1周期のサイン波を作る
      // progress * 2 * pi : アニメーションの進行に合わせて波を横にずらす
      final y = baseY + math.sin((x / size.width * 2 * math.pi) + progress * 2 * math.pi) * waveAmplitude;
      
      if (x == 0) {
        path.moveTo(x, y); // 開始地点
      } else {
        path.lineTo(x, y); // 線を繋ぐ
      }
    }

    // キャンバスに描画
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    // 進行度（progress）や色が変わった時だけ再描画する
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.isPreview != isPreview;
  }
}