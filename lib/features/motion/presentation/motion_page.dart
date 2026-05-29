import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smf_app/features/motion/application/motion_state.dart';
import '../infrastructure/motion_background_controller.dart';
import 'motion_patterns/pendulum_ball_motion.dart';
import 'motion_patterns/breathing_bottom_ball_motion.dart';
import 'motion_patterns/moving_bottom_ball_motion.dart';
import 'motion_patterns/tornado_motion.dart';
import 'motion_patterns/sleepy_breathing_balls_motion.dart';

class MotionPage extends StatefulWidget {
  const MotionPage({super.key});

  static const backgroundColor = Color(0xFFEFF2F6);

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  // 現在選択されているモーションのIDと、それがONになっているかをローカルで管理
  String _selectedPattern = 'pendulum';
  bool _isTurnedOn = false;

  // 選択されたパターンに応じて、対応する MotionState のフラグを切り替える
  static void _setMotionState(String pattern, bool isEnabled) {
    switch (pattern) {
      case 'pendulum':
        MotionState.pendulumEnabled.value = isEnabled;
        MotionState.pendulumShowInShell.value = isEnabled;
        break;
      case 'breathing_bottom':
        MotionState.breathingBottomEnabled.value = isEnabled;
        MotionState.breathingBottomShowInShell.value = isEnabled;
        break;
      case 'moving_bottom':
        MotionState.movingBottomEnabled.value = isEnabled;
        MotionState.movingBottomShowInShell.value = isEnabled;
        break;
      case 'tornado':
        MotionState.tornadoEnabled.value = isEnabled;
        MotionState.tornadoShowInShell.value = isEnabled;
        break;
      case 'sleepy_breathing':
        MotionState.sleepyBreathingEnabled.value = isEnabled;
        MotionState.sleepyBreathingShowInShell.value = isEnabled;
        break;
    }
  }

  // すべてのモーションフラグを強制的にリセットするヘルパー（排他制御）
  static void _disableAllMotions() {
    MotionState.pendulumEnabled.value = false;
    MotionState.pendulumShowInShell.value = false;
    
    MotionState.breathingBottomEnabled.value = false;
    MotionState.breathingBottomShowInShell.value = false;
    
    MotionState.movingBottomEnabled.value = false;
    MotionState.movingBottomShowInShell.value = false;
    
    MotionState.tornadoEnabled.value = false;
    MotionState.tornadoShowInShell.value = false;
    
    MotionState.sleepyBreathingEnabled.value = false;
    MotionState.sleepyBreathingShowInShell.value = false;
  }

  // 排他制御と確実なリセットを行うための統合メソッド
  Future<void> _handleToggle(String pattern, bool isEnabled) async {
    setState(() {
      _selectedPattern = isEnabled ? pattern : 'pendulum';
      _isTurnedOn = isEnabled;
    });

    _disableAllMotions();

    if (isEnabled) {
      _setMotionState(pattern, true);
      MotionState.selectedPattern.value = pattern;
      // バックグラウンドが有効なら、オーバーレイ用にパターンを保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('motion_selected_pattern', pattern);
      // バックグラウンドが有効な場合のみフォアグラウンドサービスを維持
      final bgEnabled = prefs.getBool('motion_background_enabled') ?? false;
      if (bgEnabled) {
        await MotionBackgroundController.hideOverlayForInAppExperience();
      }
    } else {
      MotionState.selectedPattern.value = 'pendulum';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('motion_selected_pattern', 'pendulum');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MotionPage.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  // --- 1枚目のカード：振り子ボール ---
                  _SkeletonCard(
                    title: '振り子ボール',
                    enabled: _isTurnedOn && _selectedPattern == 'pendulum',
                    preview: (_isTurnedOn && _selectedPattern == 'pendulum')
                        ? const _ActivePreviewPlaceholder()
                        : const PendulumBallMotion(
                            period: Duration(milliseconds: 5000),
                            ballDiameter: 20,
                            isPreview: true, // 2つ目のコードの仕様（他の背景ON時もプレビュー維持）を反映
                          ),
                    onEnabledChanged: (v) {
                      unawaited(_handleToggle('pendulum', v));
                    },
                  ),
                  
                  const SizedBox(height: 16),

                  // --- 2枚目のカード：呼吸するボール ---
                  _SkeletonCard(
                    title: '呼吸するボール',
                    enabled: _isTurnedOn && _selectedPattern == 'breathing_bottom',
                    preview: (_isTurnedOn && _selectedPattern == 'breathing_bottom')
                        ? const _ActivePreviewPlaceholder()
                        : const BreathingBottomBallMotion(
                            period: Duration(milliseconds: 4000),
                            minDiameter: 20,
                            maxDiameter: 40,
                          ),
                    onEnabledChanged: (v) {
                      unawaited(_handleToggle('breathing_bottom', v));
                    },
                  ),

                  const SizedBox(height: 16),

                  // --- 3枚目のカード：動くボール ---
                  _SkeletonCard(
                    title: '動くボール',
                    enabled: _isTurnedOn && _selectedPattern == 'moving_bottom',
                    preview: (_isTurnedOn && _selectedPattern == 'moving_bottom')
                        ? const _ActivePreviewPlaceholder()
                        : const MovingBottomBallMotion(
                            period: Duration(milliseconds: 3000),
                            minDiameter: 20,
                            maxDiameter: 100,
                          ),
                    onEnabledChanged: (v) {
                      unawaited(_handleToggle('moving_bottom', v));
                    },
                  ),

                  const SizedBox(height: 16),

                  // --- 4枚目のカード：竜巻モーション ---
                  _SkeletonCard(
                    title: '竜巻モーション',
                    enabled: _isTurnedOn && _selectedPattern == 'tornado',
                    preview: (_isTurnedOn && _selectedPattern == 'tornado')
                        ? const _ActivePreviewPlaceholder()
                        : const TornadoTopViewMotion(
                            period: Duration(milliseconds: 3000),
                            minScale: 0.3,
                            maxScale: 1.2,
                          ),
                    onEnabledChanged: (v) {
                      unawaited(_handleToggle('tornado', v));
                    },
                  ),

                  const SizedBox(height: 16),

                  // --- 5枚目のカード：おやすみ呼吸ボール ---
                  _SkeletonCard(
                    title: 'おやすみ呼吸ボール',
                    enabled: _isTurnedOn && _selectedPattern == 'sleepy_breathing',
                    preview: (_isTurnedOn && _selectedPattern == 'sleepy_breathing')
                        ? const _ActivePreviewPlaceholder()
                        : const SleepyBreathingBallsMotion(
                            period: Duration(milliseconds: 12000),
                            maxDiameter: 80,
                          ),
                    onEnabledChanged: (v) {
                      unawaited(_handleToggle('sleepy_breathing', v));
                    },
                  ),
                  
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivePreviewPlaceholder extends StatelessWidget {
  const _ActivePreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 36,
            color: Colors.blueGrey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            '表示中',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.blueGrey.shade600,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

// 2つ目のコードの改良版 SkeletonCard (高さ220での BOTTOM OVERFLOWED 対策等が含まれています)
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.title,
    required this.enabled,
    required this.preview,
    required this.onEnabledChanged,
  });

  final String title;
  final bool enabled;
  final Widget preview;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220, 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (enabled ? Colors.green.shade600 : Colors.grey.shade500)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (enabled ? Colors.green.shade700 : Colors.grey.shade600)
                              .withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        enabled ? 'ON' : 'OFF',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: enabled ? Colors.green.shade700 : Colors.grey.shade700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 138,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.04),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          preview,
                          Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SkeletonBar(widthFactor: 0.7),
                                  const SizedBox(height: 10),
                                  const _SkeletonBar(widthFactor: 0.95),
                                  const SizedBox(height: 10),
                                  const _SkeletonBar(widthFactor: 0.82),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      _SkeletonDot(),
                                      const SizedBox(width: 8),
                                      _SkeletonDot(),
                                      const SizedBox(width: 8),
                                      _SkeletonDot(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled ? Icons.toggle_on : Icons.toggle_off,
                    size: 18,
                    color: enabled ? Colors.green.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Switch.adaptive(
                    value: enabled,
                    onChanged: onEnabledChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor.clamp(0.1, 1.0),
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _SkeletonDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
    );
  }
}