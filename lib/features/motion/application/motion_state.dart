import 'package:flutter/foundation.dart';
import '../presentation/motion_pattern_registry.dart';

/// モーションパターンの状態管理。
/// パターンはレジストリから自動生成されるため、新規追加時にこのファイルは変更不要。
class MotionState {
  /// パターンID → ON/OFF 状態
  static final Map<String, ValueNotifier<bool>> enabled = {
    for (final p in motionPatterns) p.id: ValueNotifier(false),
  };

  /// パターンID → アプリ内シェルへの表示状態
  static final Map<String, ValueNotifier<bool>> showInShell = {
    for (final p in motionPatterns) p.id: ValueNotifier(false),
  };

  /// 現在選択中のパターンID
  static final ValueNotifier<String> selectedPattern =
      ValueNotifier(motionPatterns.first.id);

  /// 有効なパターンが1つでもあるか
  static bool get anyEnabled =>
      motionPatterns.any((p) => enabled[p.id]?.value == true);

  /// すべてのパターンをOFFにする
  static void disableAll() {
    for (final p in motionPatterns) {
      enabled[p.id]?.value = false;
      showInShell[p.id]?.value = false;
    }
  }
}
