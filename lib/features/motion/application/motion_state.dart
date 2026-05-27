import 'package:flutter/material.dart';

class MotionState {
  static final pendulumEnabled = ValueNotifier<bool>(false);
  static final pendulumShowInShell = ValueNotifier<bool>(true);

  // ★ 追加：現在アクティブなパターンの名前を管理する（初期値は pendulum）
  static final selectedPattern = ValueNotifier<String>('pendulum');
}