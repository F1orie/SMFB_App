import 'package:flutter/foundation.dart';

class MotionState {
  // 背景アニメーション全体のON/OFF状態を管理
  static final ValueNotifier<bool> pendulumEnabled = ValueNotifier<bool>(false);
  
  // アプリの大枠（シェル）での表示状態を管理
  static final ValueNotifier<bool> pendulumShowInShell = ValueNotifier<bool>(false);
  
  // 現在選択されているモーションのパターンIDを管理（今回追加した部分）
  static final ValueNotifier<String> selectedPattern = ValueNotifier<String>('pendulum');


  // ==========================================
  // 以下、エラーを解消するために追加するプロパティ
  // ==========================================

  // --- 呼吸するボール ---
  static final ValueNotifier<bool> breathingBottomEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> breathingBottomShowInShell = ValueNotifier<bool>(false);

  // --- 動くボール ---
  static final ValueNotifier<bool> movingBottomEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> movingBottomShowInShell = ValueNotifier<bool>(false);

  // --- 竜巻モーション ---
  static final ValueNotifier<bool> tornadoEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> tornadoShowInShell = ValueNotifier<bool>(false);

  // --- おやすみ呼吸ボール ---
  static final ValueNotifier<bool> sleepyBreathingEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> sleepyBreathingShowInShell = ValueNotifier<bool>(false);
}