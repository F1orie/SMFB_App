import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:smf_app/common/navigation/main_tab_index_notifier.dart';
import 'package:smf_app/common/ui/navigation/app_bottom_navigation_bar.dart';
import 'package:smf_app/features/alarm/domain/sleep_session.dart';
import 'package:smf_app/features/alarm/presentation/alarm_page.dart';
import 'package:smf_app/features/fb/presentation/pages/fb_dashboard_page.dart';
import 'package:smf_app/features/graph/presentation/graph_page.dart';
import 'package:smf_app/features/motion/application/motion_state.dart';
import 'package:smf_app/features/motion/infrastructure/motion_background_controller.dart';
import 'package:smf_app/features/motion/presentation/motion_page.dart';
import 'package:smf_app/features/motion/presentation/motion_pattern_registry.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smf_app/features/list/presentation/list_page.dart';
import 'package:smf_app/features/settings/presentation/settings_page.dart';

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja'),
        Locale('en'),
      ],
      locale: const Locale('ja'),
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

  int _fbRebuildKey = 0;
  int _graphRebuildKey = 0;
  DateTime? _graphTargetDate;
  SleepSession? _fbTargetSession;

  void _navigateToFb() {
    _fbTargetSession = null;
    _fbRebuildKey++;
    _mainTab.select(4);
  }

  void _navigateToGraphDate(DateTime date) {
    _graphTargetDate = date;
    _graphRebuildKey++;
    _mainTab.select(1);
    setState(() {});
  }

  void _navigateToFbSession(SleepSession session) {
    _fbTargetSession = session;
    _fbRebuildKey++;
    _mainTab.select(4);
    setState(() {});
  }

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
    for (final p in motionPatterns) {
      if (MotionState.enabled[p.id]?.value == true) {
        MotionState.showInShell[p.id]?.value = true;
      }
    }
  }

  Future<void> _onAppPaused() async {
    if (!MotionBackgroundController.triesSystemOverlay) return;
    final prefs = await SharedPreferences.getInstance();
    final bgEnabled = prefs.getBool('motion_background_enabled') ?? false;
    if (!bgEnabled) return;
    if (!MotionState.anyEnabled) return;
    for (final p in motionPatterns) {
      MotionState.showInShell[p.id]?.value = false;
    }
    await MotionBackgroundController.showOverlayWhenAppBackgrounded();
    final selectedPattern = prefs.getString('motion_selected_pattern') ?? motionPatterns.first.id;
    await FlutterOverlayWindow.shareData(selectedPattern);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _mainTab,
      builder: (context, _) {
        final index = _mainTab.index;
        return ListenableBuilder(
          listenable: Listenable.merge([
            for (final p in motionPatterns) ...[
              MotionState.enabled[p.id]!,
              MotionState.showInShell[p.id]!,
            ],
          ]),
          builder: (context, _) {
            return Scaffold(
              backgroundColor: MotionState.anyEnabled ? Colors.transparent : null,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  IndexedStack(
                    index: index,
                    children: [
                      AlarmPage(
                        onNavigateToGraph: () => _mainTab.select(1),
                        onNavigateToFb: _navigateToFb,
                      ),
                      GraphPage(
                        key: ValueKey(_graphRebuildKey),
                        initialDate: _graphTargetDate,
                      ),
                      ListPage(
                        onNavigateToGraph: _navigateToGraphDate,
                        onNavigateToFb: _navigateToFbSession,
                      ),
                      const SettingsPage(),
                      FbDashboardPage(
                        key: ValueKey(_fbRebuildKey),
                        targetSession: _fbTargetSession,
                      ),
                      const MotionPage(),
                    ],
                  ),
                  // レジストリから自動生成：新パターン追加時に変更不要
                  for (final p in motionPatterns)
                    if (MotionState.enabled[p.id]?.value == true &&
                        MotionState.showInShell[p.id]?.value == true)
                      Positioned.fill(
                        child: IgnorePointer(child: p.build()),
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
