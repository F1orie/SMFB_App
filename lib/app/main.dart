import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smf_app/common/navigation/main_tab_index_notifier.dart';
import 'package:smf_app/common/ui/navigation/app_bottom_navigation_bar.dart';
import 'package:smf_app/features/alarm/presentation/alarm_page.dart';
import 'package:smf_app/features/graph/presentation/graph_page.dart';
import 'package:smf_app/features/motion/application/motion_state.dart';
import 'package:smf_app/features/motion/infrastructure/motion_background_controller.dart';
import 'package:smf_app/features/motion/presentation/motion_page.dart';
import 'package:smf_app/features/motion/presentation/motion_patterns/pendulum_ball_motion.dart';

class SmfApp extends StatelessWidget {
  const SmfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smf_app',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

/// タブシェル：common のナビと各 feature 画面を結線する。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final MainTabIndexNotifier _mainTab = MainTabIndexNotifier();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainTab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onAppResumed());
    } else if (state == AppLifecycleState.paused) {
      unawaited(_onAppPaused());
    }
  }

  Future<void> _onAppResumed() async {
    await MotionBackgroundController.hideOverlayForInAppExperience();
    if (MotionState.pendulumEnabled.value) {
      MotionState.pendulumShowInShell.value = true;
    }
  }

  Future<void> _onAppPaused() async {
    if (!MotionState.pendulumEnabled.value) return;
    if (!MotionBackgroundController.triesSystemOverlay) return;
    MotionState.pendulumShowInShell.value = false;
    await MotionBackgroundController.showOverlayWhenAppBackgrounded();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _mainTab,
      builder: (context, _) {
        final index = _mainTab.index;
        return ListenableBuilder(
          listenable: Listenable.merge([
            MotionState.pendulumEnabled,
            MotionState.pendulumShowInShell,
          ]),
          builder: (context, _) {
            final pendulum = MotionState.pendulumEnabled.value;
            final showInShell = MotionState.pendulumShowInShell.value;
            // 振り子は IndexedStack の「上」に重ねる（各タブ背景は不透明のまま）。
            // Android: バックグラウンド時のみシステムオーバーレイを出す（前面ではシェルと二重にならない）。
            // IgnorePointer でタップは下の画面へ通す。
            return Scaffold(
              backgroundColor: pendulum ? Colors.transparent : null,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  IndexedStack(
                    index: index,
                    children: [
                      const AlarmPage(),
                      GraphPage(),
                      _PlaceholderTab(label: 'リスト'),
                      _PlaceholderTab(label: '統計'),
                      _PlaceholderTab(label: '設定'),
                      _PlaceholderTab(label: 'フィードバック'),
                      const MotionPage(),
                    ],
                  ),
                  if (pendulum && showInShell)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: PendulumBallMotion(
                          period: Duration(milliseconds: 5000),
                        ),
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: AppBottomNavigationBar(
                currentIndex: index,
                onDestinationSelected: _mainTab.select,
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Text(
          '$label（未実装）',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
