import 'dart:math' as math;
import 'package:flutter/material.dart';

// ==========================================
// バウンドボール
// ==========================================

/// 画面内をランダムな角度で反射して動き回る球体モーション。
///
/// - 速度の基準: [period]（短いほど速く動きます）
/// - 初期進行角度: [maxAngleRad]
class BouncingBallMotion extends StatefulWidget {
  const BouncingBallMotion({
    super.key,
    this.period = const Duration(milliseconds: 5000),
    this.ballDiameter = 26,
    this.ballColor = const Color(0xFFBFE6FF),
    this.glowColor = const Color(0xFF6EC6FF),
    this.maxAngleRad = 0.95,
  });

  final Duration period;
  final double ballDiameter;
  final Color ballColor;
  final Color glowColor;
  final double maxAngleRad;

  @override
  State<BouncingBallMotion> createState() => _BouncingBallMotionState();
}

class _BouncingBallMotionState extends State<BouncingBallMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Duration _lastTime = Duration.zero;

  // --- 物理シミュレーション用の状態 ---
  double _nx = 0.5;
  double _ny = 0.5;

  double _vx = 0.0;
  double _vy = 0.0;

  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(days: 9999))
      ..addListener(_updatePhysics)
      ..forward();

    _initVelocity();
  }

  @override
  void didUpdateWidget(covariant BouncingBallMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _updateSpeedMultiplier();
    }
  }

  void _initVelocity() {
    final durationSec = widget.period.inMilliseconds / 1000.0;
    final speed = durationSec > 0 ? 1.0 / durationSec : 0.2;

    final angle = widget.maxAngleRad;
    _vx = speed * math.cos(angle);
    _vy = speed * math.sin(angle);
  }

  void _updateSpeedMultiplier() {
    final durationSec = widget.period.inMilliseconds / 1000.0;
    final newSpeed = durationSec > 0 ? 1.0 / durationSec : 0.2;

    final currentSpeed = math.sqrt(_vx * _vx + _vy * _vy);
    if (currentSpeed > 0) {
      _vx = (_vx / currentSpeed) * newSpeed;
      _vy = (_vy / currentSpeed) * newSpeed;
    } else {
      _initVelocity();
    }
  }

  void _updatePhysics() {
    final elapsed = _ctrl.lastElapsedDuration ?? Duration.zero;
    final dt = math.min((elapsed - _lastTime).inMicroseconds / 1000000.0, 0.05);
    _lastTime = elapsed;

    if (dt <= 0) return;

    _nx += _vx * dt;
    _ny += _vy * dt;

    bool hitLeft = _nx <= 0.0 && _vx < 0;
    bool hitRight = _nx >= 1.0 && _vx > 0;
    bool hitTop = _ny <= 0.0 && _vy < 0;
    bool hitBottom = _ny >= 1.0 && _vy > 0;

    bool bounced = false;

    // 反射前の進行方向（符号）を保存
    double oldVx = _vx;
    double oldVy = _vy;

    if (hitLeft || hitRight) {
      _vx = -_vx;
      bounced = true;
    }
    if (hitTop || hitBottom) {
      _vy = -_vy;
      bounced = true;
    }

    if (bounced) {
      _nx = _nx.clamp(0.0, 1.0);
      _ny = _ny.clamp(0.0, 1.0);

      final currentSpeed = math.sqrt(_vx * _vx + _vy * _vy);
      final baseAngle = math.atan2(_vy, _vx); // 理想的な反射角

      double finalVx = _vx;
      double finalVy = _vy;

      // 不自然な反射を防ぐため、条件を満たすまで最大20回リトライする
      for (int i = 0; i < 20; i++) {
        // 【修正】揺らぎの幅を ±15度（math.pi / 6）に縮小して、極端な変化を防ぐ
        final jitter = (_random.nextDouble() - 0.5) * (math.pi / 6); 
        final testAngle = baseAngle + jitter;

        final testVx = currentSpeed * math.cos(testAngle);
        final testVy = currentSpeed * math.sin(testAngle);

        bool safe = true;

        // 1. 壁から確実に脱出できるか（めり込み防止）
        if (hitLeft && testVx <= 0) safe = false;
        if (hitRight && testVx >= 0) safe = false;
        if (hitTop && testVy <= 0) safe = false;
        if (hitBottom && testVy >= 0) safe = false;

        // 2. 後ろに反射しないか（進行方向の維持）
        if ((hitLeft || hitRight) && !(hitTop || hitBottom)) {
          if (oldVy > 0 && testVy <= 0) safe = false;
          if (oldVy < 0 && testVy >= 0) safe = false;
        }
        if ((hitTop || hitBottom) && !(hitLeft || hitRight)) {
          if (oldVx > 0 && testVx <= 0) safe = false;
          if (oldVx < 0 && testVx >= 0) safe = false;
        }

        // 3. 【追加】つばめ返し（極端な鋭角や、垂直・水平すぎる反射）の防止
        // 速度のX成分、またはY成分が全体の速度の25%未満（角度にして約15度以下）
        // になるような「壁沿いを滑る動き」や「真上に跳ね返る動き」をNGとする
        if (testVx.abs() < currentSpeed * 0.25 || testVy.abs() < currentSpeed * 0.25) {
          safe = false;
        }

        if (safe) {
          finalVx = testVx;
          finalVy = testVy;
          break;
        }
      }

      _vx = finalVx;
      _vy = finalVy;
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
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        final diameter = widget.ballDiameter.clamp(6.0, 200.0).toDouble();

        final maxX = math.max(0.0, w - diameter);
        final maxY = math.max(0.0, h - diameter);

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final x = _nx * maxX;
            final y = _ny * maxY;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: x.isFinite ? x : 0,
                  top: y.isFinite ? y : 0,
                  child: _Ball(
                    diameter: diameter,
                    color: widget.ballColor,
                    glowColor: widget.glowColor,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Ball extends StatelessWidget {
  const _Ball({
    required this.diameter,
    required this.color,
    required this.glowColor,
  });

  final double diameter;
  final Color color;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.96),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }
}