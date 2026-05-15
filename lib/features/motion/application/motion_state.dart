import 'package:flutter/foundation.dart';

/// 全タブ共通で参照するモーション表示フラグ（振り子など）。
class MotionState {
  MotionState._();

  /// 振り子モーションをシェル背面に表示するか。
  static final ValueNotifier<bool> pendulumEnabled = ValueNotifier<bool>(false);

  /// Android でアプリが背後（paused）の間は false。前面ではシェル描画、背後では
  /// システムオーバーレイのみとし二重表示を防ぐ。
  static final ValueNotifier<bool> pendulumShowInShell = ValueNotifier<bool>(
    true,
  );
}
