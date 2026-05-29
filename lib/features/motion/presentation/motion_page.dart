import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smf_app/features/motion/application/motion_state.dart';
import '../infrastructure/motion_background_controller.dart';
import 'motion_pattern_registry.dart';

class MotionPage extends StatefulWidget {
  const MotionPage({super.key});

  static const backgroundColor = Color(0xFF071C35);

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  String _selectedPattern = motionPatterns.first.id;
  bool _isTurnedOn = false;

  Future<void> _handleToggle(String patternId, bool isEnabled) async {
    setState(() {
      _selectedPattern = isEnabled ? patternId : motionPatterns.first.id;
      _isTurnedOn = isEnabled;
    });

    // 排他制御：全パターンをOFF
    MotionState.disableAll();

    if (isEnabled) {
      MotionState.enabled[patternId]?.value = true;
      MotionState.showInShell[patternId]?.value = true;
      MotionState.selectedPattern.value = patternId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('motion_selected_pattern', patternId);

      final bgEnabled = prefs.getBool('motion_background_enabled') ?? false;
      if (bgEnabled) {
        await MotionBackgroundController.hideOverlayForInAppExperience();
      }
    } else {
      MotionState.selectedPattern.value = motionPatterns.first.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('motion_selected_pattern', motionPatterns.first.id);
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
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // カード間のスペース
                    if (index.isOdd) return const SizedBox(height: 16);
                    final pattern = motionPatterns[index ~/ 2];
                    final isActive = _isTurnedOn && _selectedPattern == pattern.id;
                    return _SkeletonCard(
                      title: pattern.label,
                      enabled: isActive,
                      preview: isActive
                          ? const _ActivePreviewPlaceholder()
                          : pattern.buildPreview(),
                      onEnabledChanged: (v) {
                        unawaited(_handleToggle(pattern.id, v));
                      },
                    );
                  },
                  childCount: motionPatterns.length * 2 - 1,
                ),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                            ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (enabled ? Colors.greenAccent : Colors.white)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: (enabled ? Colors.greenAccent : Colors.white)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        enabled ? 'ON' : 'OFF',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: enabled ? Colors.greenAccent : Colors.white60,
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
                      color: Colors.white.withValues(alpha: 0.04),
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
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
          color: Colors.white.withValues(alpha: 0.12),
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
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
    );
  }
}