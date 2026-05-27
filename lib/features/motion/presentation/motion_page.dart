import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smf_app/features/motion/application/motion_state.dart';

import '../infrastructure/motion_background_controller.dart';
import 'motion_patterns/breathing_pendulum_motion.dart';
import 'motion_patterns/pendulum_ball_motion.dart';
// ★ 3枚目の縦線アニメーションをインポート
import 'motion_patterns/side_breathing_lines_motion.dart'; 

class MotionPage extends StatefulWidget {
  const MotionPage({super.key});

  static const backgroundColor = Color(0xFFEFF2F6);

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  // 現在どのパターンが選択されているかを保持する状態 ('pendulum', 'breathing', 'side_lines')
  String _selectedPattern = 'pendulum';

  static Future<void> _setPendulumEnabled(bool enabled) async {
    if (enabled) {
      MotionState.pendulumEnabled.value = true;
      MotionState.pendulumShowInShell.value = true;
      await MotionBackgroundController.enable();
      await MotionBackgroundController.hideOverlayForInAppExperience();
    } else {
      MotionState.pendulumShowInShell.value = true;
      MotionState.pendulumEnabled.value = false;
      await MotionBackgroundController.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MotionState.pendulumEnabled,
      builder: (context, enabled, _) {
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
                      
                      // 1枚目のカード：通常の振り子ボール
                      _SkeletonCard(
                        title: '振り子ボール',
                        enabled: enabled && _selectedPattern == 'pendulum',
                        preview: (enabled && _selectedPattern == 'pendulum')
                            ? const _PendulumActivePreviewPlaceholder()
                            : const PendulumBallMotion(
                                period: Duration(milliseconds: 5000),
                                ballDiameter: 20,
                                isPreview: true, // ★ 他がONになってもここは絶対に振り子を維持するフラグ
                              ),
                        onEnabledChanged: (v) {
                          setState(() {
                            _selectedPattern = 'pendulum';
                          });
                          // 全体状態に通知（干渉を防ぐため確実に pendulum にリセット）
                          MotionState.selectedPattern.value = 'pendulum';
                          unawaited(_setPendulumEnabled(v));
                        },
                      ),
                      
                      const SizedBox(height: 16), // カード間の余白

                      // 2枚目のカード：明滅する固定点
                      _SkeletonCard(
                        title: '明滅するボール',
                        enabled: enabled && _selectedPattern == 'breathing',
                        preview: (enabled && _selectedPattern == 'breathing')
                            ? const _PendulumActivePreviewPlaceholder()
                            : const BreathingPendulumMotion(
                                period: Duration(milliseconds: 5000),
                                ballDiameter: 14,
                              ),
                        onEnabledChanged: (v) {
                          setState(() {
                            // スイッチON時は 'breathing'、OFFにされたらデフォルトの 'pendulum' に引き戻す
                            _selectedPattern = v ? 'breathing' : 'pendulum';
                          });
                          // 全体状態に通知
                          MotionState.selectedPattern.value = v ? 'breathing' : 'pendulum';
                          unawaited(_setPendulumEnabled(v));
                        },
                      ),

                      const SizedBox(height: 16), // カード間の余白

                      // ★ 3枚目のカード：波打つ縦線（追加箇所）
                      _SkeletonCard(
                        title: '波打つ縦線', // お好みの名前に変更してください
                        enabled: enabled && _selectedPattern == 'side_lines',
                        preview: (enabled && _selectedPattern == 'side_lines')
                            ? const _PendulumActivePreviewPlaceholder()
                            : const SideBreathingLinesMotion(
                                period: Duration(milliseconds: 6000),
                              ),
                        onEnabledChanged: (v) {
                          setState(() {
                            // スイッチON時は 'side_lines'、OFFにされたら 'pendulum' に戻す
                            _selectedPattern = v ? 'side_lines' : 'pendulum';
                          });
                          // 全体状態に通知
                          MotionState.selectedPattern.value = v ? 'side_lines' : 'pendulum';
                          unawaited(_setPendulumEnabled(v));
                        },
                      ),

                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ON 時は全画面／オーバーレイ側で振り子やドットが出るため、カード内では二重にならないプレースホルダ。
class _PendulumActivePreviewPlaceholder extends StatelessWidget {
  const _PendulumActivePreviewPlaceholder();

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
      height: 220, // 固定高さを 220 に拡張して、BOTTOM OVERFLOWED エラーを完全防止
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
                        color:
                            (enabled
                                    ? Colors.green.shade600
                                    : Colors.grey.shade500)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              (enabled
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600)
                                  .withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        enabled ? 'ON' : 'OFF',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: enabled
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
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
                                  _SkeletonBar(widthFactor: 0.7),
                                  const SizedBox(height: 10),
                                  _SkeletonBar(widthFactor: 0.95),
                                  const SizedBox(height: 10),
                                  _SkeletonBar(widthFactor: 0.82),
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