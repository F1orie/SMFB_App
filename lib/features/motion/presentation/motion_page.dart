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

  // 8色パレット
  static const _palette = [
    Color(0xFFFFB74D), // オレンジ
    Color(0xFF4FC3F7), // ブルー
    Color(0xFFA78BFA), // パープル
    Color(0xFF6EE7B7), // グリーン
    Color(0xFFFCA5A5), // ピンク
    Color(0xFFFFF176), // イエロー
    Color(0xFFFF8A65), // コーラル
    Color(0xFFE0E0E0), // ホワイト系
  ];

  Future<void> _handleToggle(String patternId, bool isEnabled) async {
    setState(() {
      _selectedPattern = isEnabled ? patternId : motionPatterns.first.id;
      _isTurnedOn = isEnabled;
    });

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
                    if (index.isOdd) return const SizedBox(height: 16);
                    final pattern = motionPatterns[index ~/ 2];
                    final isActive = _isTurnedOn && _selectedPattern == pattern.id;
                    return ValueListenableBuilder<Color>(
                      valueListenable: MotionState.color[pattern.id]!,
                      builder: (context, currentColor, _) {
                        return _SkeletonCard(
                          title: pattern.label,
                          enabled: isActive,
                          currentColor: currentColor,
                          palette: _palette,
                          preview: isActive
                              ? const _ActivePreviewPlaceholder()
                              : pattern.buildPreview(currentColor),
                          onEnabledChanged: (v) {
                            unawaited(_handleToggle(pattern.id, v));
                          },
                          onColorSelected: (color) {
                            unawaited(MotionState.setColor(pattern.id, color));
                          },
                        );
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
          Icon(Icons.visibility_outlined, size: 36, color: Colors.blueGrey.shade400),
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
    required this.currentColor,
    required this.palette,
    required this.preview,
    required this.onEnabledChanged,
    required this.onColorSelected,
  });

  final String title;
  final bool enabled;
  final Color currentColor;
  final List<Color> palette;
  final Widget preview;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル + ON/OFF バッジ
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: enabled ? Colors.greenAccent : Colors.white60,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // プレビュー
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
                              Row(children: [
                                _SkeletonDot(), const SizedBox(width: 8),
                                _SkeletonDot(), const SizedBox(width: 8),
                                _SkeletonDot(),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // カラーパレット + トグルスイッチ
            Row(
              children: [
                // カラースウォッチ
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: palette.map((c) {
                      final isSelected = currentColor.toARGB32() == c.toARGB32();
                      return GestureDetector(
                        onTap: () => onColorSelected(c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.2),
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                // スイッチ
                Container(
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
              ],
            ),
          ],
        ),
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
