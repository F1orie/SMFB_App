    import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:smf_app/common/navigation/main_tab_index_notifier.dart';
import 'package:smf_app/common/ui/navigation/app_bottom_navigation_bar.dart';
import 'package:smf_app/features/alarm/domain/sleep_session.dart';
import 'package:smf_app/features/alarm/presentation/alarm_page.dart';
import 'package:smf_app/features/fb/presentation/pages/fb_dashboard_page.dart';
import 'package:smf_app/features/graph/presentation/graph_page.dart';
import 'package:smf_app/features/list/presentation/list_page.dart';

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

class _MainShellState extends State<MainShell> {
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
  void dispose() {
    _mainTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _mainTab,
      builder: (context, _) {
        final index = _mainTab.index;
        return Scaffold(
          body: IndexedStack(
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
              _PlaceholderTab(label: '設定'),
              FbDashboardPage(
                key: ValueKey(_fbRebuildKey),
                targetSession: _fbTargetSession,
              ),
              _PlaceholderTab(label: 'モーション'),
            ],
          ),
          bottomNavigationBar: AppBottomNavigationBar(
            currentIndex: index,
            onDestinationSelected: _mainTab.select,
          ),
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
