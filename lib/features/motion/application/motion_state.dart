import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// パターンID → 選択色
  static final Map<String, ValueNotifier<Color>> color = {
    for (final p in motionPatterns) p.id: ValueNotifier(p.defaultColor),
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

  /// 色を変更してSharedPreferencesに保存する
  static Future<void> setColor(String patternId, Color newColor) async {
    color[patternId]?.value = newColor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('motion_color_$patternId', newColor.toARGB32());
  }

  /// SharedPreferencesから色を読み込む
  static Future<void> loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    for (final p in motionPatterns) {
      final saved = prefs.getInt('motion_color_${p.id}');
      if (saved != null) {
        color[p.id]?.value = Color(saved);
      }
    }
  }
}
