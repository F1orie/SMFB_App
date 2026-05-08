import 'package:flutter/foundation.dart';

/// メインシェルのタブ選択（UI 状態のみ）。ドメインロジックは含めない。
class MainTabIndexNotifier extends ChangeNotifier {
  MainTabIndexNotifier({int initialIndex = 0}) : _index = initialIndex;

  int _index;

  int get index => _index;

  void select(int tabIndex) {
    if (_index == tabIndex) return;
    _index = tabIndex;
    notifyListeners();
  }
}
