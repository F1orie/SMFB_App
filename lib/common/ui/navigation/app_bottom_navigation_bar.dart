import 'package:flutter/material.dart';

/// アプリ全体の 5 タブ（アラーム／グラフ／リスト／統計／設定）。
///
/// 機能画面の中身は app 層で組み立て、この Widget は見た目だけを提供する。
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.alarm_outlined),
      selectedIcon: Icon(Icons.alarm),
      label: 'アラーム',
    ),
    NavigationDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: 'グラフ',
    ),
    NavigationDestination(
      icon: Icon(Icons.format_list_bulleted_outlined),
      selectedIcon: Icon(Icons.format_list_bulleted),
      label: 'リスト',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '設定',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: '分析',
    ),
    NavigationDestination(
      icon: Icon(Icons.refresh_outlined),
      selectedIcon: Icon(Icons.refresh),
      label: 'モーション',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.92,
    );
    final selectedTint = Colors.blue.shade700;

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: selectedTint.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return theme.textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? selectedTint : theme.colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? selectedTint : theme.colorScheme.onSurfaceVariant,
            size: selected ? 26 : 24,
          );
        }),
        height: 64,
      ),
      child: NavigationBar(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: background,
        selectedIndex: currentIndex.clamp(0, _destinations.length - 1),
        onDestinationSelected: onDestinationSelected,
        destinations: _destinations.toList(growable: false),
      ),
    );
  }
}
