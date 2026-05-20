# モーション機能（`lib/features/motion`）

睡眠・覚醒支援を想定した **視覚刺激モーション** を提供する機能です。  
ユーザーがモーションタブで ON にすると、**全タブの前面**にアニメーションが重なり、Android では **アプリを背後に回したあとも** 他アプリの上に表示し続けられるようにしています。

---

## 何を実装しているか（概要）


| 観点       | 内容                                                                |
| -------- | ----------------------------------------------------------------- |
| 目的       | 画面にゆっくり動く視覚刺激（現状は「振り子ボール」）を出し、バックグラウンドでも継続させる                     |
| ユーザー操作   | モーションタブ（最下段タブ）のカードで ON/OFF                                        |
| 表示場所     | ① 全タブ共通の重ね層（`MainShell`）② モーションタブ内のプレビュー ③ Android 背後時のシステムオーバーレイ |
| バックグラウンド | ウェイクロック・フォアグラウンドサービス（FGS）・オーバーレイ権限（Android）                       |


現状は **振り子 1 種類のみ** ですが、フォルダ構成は将来のモーション追加を見据えたレイヤ分けになっています。

---

## フォルダ構成

```
motion/
├── README.md                 … 本ファイル（人間向けの入口）
├── application/              … アプリ全体で共有する状態
├── domain/                   … ドメインモデル（未実装・プレースホルダ）
├── infrastructure/           … OS・プラグイン連携（描画ロジックなし）
└── presentation/             … 画面 UI と個別モーションの見た目
    └── motion_patterns/      … モーションごとの Widget
```

レイヤの役割は次のとおりです。


| レイヤ                | 役割                | 置くものの例                         |
| ------------------ | ----------------- | ------------------------------ |
| **presentation**   | 画面・Widget・アニメーション | `MotionPage`、`*_motion.dart`   |
| **application**    | 機能横断の状態・ユースケース    | `MotionState`（`ValueNotifier`） |
| **domain**         | ビジネスルール・エンティティ    | 将来: `MotionId`、選択ルールなど         |
| **infrastructure** | デバイス・プラグイン        | FGS、オーバーレイ、Wakelock            |


---

## ファイル一覧

### `application/`


| ファイル                | 内容                                                                                                                                 |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `motion_state.dart` | 全タブから参照する **表示フラグ**。`pendulumEnabled`（振り子 ON/OFF）、`pendulumShowInShell`（シェル上に描画するか。Android でアプリが背後の間は `false` にしてオーバーレイとの二重表示を防ぐ）。 |


### `domain/`


| ファイル       | 内容                               |
| ---------- | -------------------------------- |
| `.gitkeep` | ドメイン層用の空フォルダ。現時点ではモデル・リポジトリは未配置。 |


### `infrastructure/`


| ファイル                                | 内容                                                                                                                                                                             |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `motion_background_controller.dart` | **描画は行わず**、モーション継続のための基盤だけを制御。`enable()`（Wakelock + オーバーレイ権限取得 + Android FGS 開始）、`disable()`、`showOverlayWhenAppBackgrounded()` / `hideOverlayForInAppExperience()`（前面・背後の切替）。 |


### `presentation/`


| ファイル                                        | 内容                                                                                                        |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `motion_page.dart`                          | モーションタブの UI。カード一覧・Switch・プレビュー。ON/OFF 時に `MotionState` を更新し `MotionBackgroundController` を呼ぶ **単一の操作入口**。 |
| `motion_patterns/pendulum_ball_motion.dart` | 振り子ボールの **見た目とアニメーション**（`AnimationController` + 円弧運動）。親から渡された矩形いっぱいに描画するだけの Widget。                       |


---

## このフォルダの外だが関係するファイル

モーションは feature 単体では完結せず、エントリとシェルと結線されています。


| パス                                                        | 関係                                                                                                                                     |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/app/main.dart`                                       | `MainShell`: 全タブの `IndexedStack` の **上** に振り子を重ねる。`WidgetsBindingObserver` で `paused` / `resumed` 時にオーバーレイと `pendulumShowInShell` を切替。 |
| `lib/main.dart`                                           | `overlayMain()`: Android システムオーバーレイ用の **別エントリ**。`PendulumBallMotion` のみ（`MotionState` は参照しない）。                                         |
| `lib/common/ui/navigation/app_bottom_navigation_bar.dart` | 最下段タブ「モーション」→ `MotionPage` へ遷移。                                                                                                        |
| `pubspec.yaml`                                            | `wakelock_plus`, `flutter_foreground_task`, `flutter_overlay_window`                                                                   |
| `android/app/src/main/AndroidManifest.xml`                | 権限・FGS・オーバーレイサービス定義                                                                                                                    |


---

## 動きの流れ（振り子 ON のとき）

```
[モーションタブ] Switch ON
    → MotionState.pendulumEnabled = true
    → MotionState.pendulumShowInShell = true
    → MotionBackgroundController.enable()
    → hideOverlayForInAppExperience()   // 前面ではオーバーレイは出さない

[MainShell] 全タブの上に PendulumBallMotion（IgnorePointer でタップは下へ）

[アプリが背後へ] AppLifecycleState.paused（Android）
    → pendulumShowInShell = false        // シェル側は止める
    → showOverlayWhenAppBackgrounded()   // overlayMain の Widget を表示

[前面に復帰] resumed
    → hideOverlayForInAppExperience()
    → pendulum ON なら pendulumShowInShell = true

[モーションタブ] Switch OFF
    → MotionBackgroundController.disable()
```

### 描画が起きる 3 か所

同じ振り子でも **コンテキストが 3 つ** あります（将来モーション追加時も意識が必要です）。


| #   | いつ                                        | どこ                                                   |
| --- | ----------------------------------------- | ---------------------------------------------------- |
| A   | モーション ON・前面・`pendulumShowInShell == true` | `MainShell` の `Stack` 上段（全タブ共通）                      |
| B   | モーションタブのカード内（UI）                          | `MotionPage`（OFF 時はプレビュー、ON 時は「表示中」プレースホルダで二重表示を避ける） |
| C   | モーション ON・アプリが背後（Android）                  | `lib/main.dart` の `overlayMain()`                    |


---

## 読み始める順番（おすすめ）

1. `presentation/motion_patterns/pendulum_ball_motion.dart` … 実際のアニメーション
2. `application/motion_state.dart` … 共有フラグ
3. `presentation/motion_page.dart` … ユーザーが触る UI と ON/OFF 処理
4. `infrastructure/motion_background_controller.dart` … バックグラウンド基盤
5. `lib/app/main.dart` の `MainShell` … 全タブへの重ねとライフサイクル
6. `lib/main.dart` の `overlayMain()` … オーバーレイ専用エントリ

---

## 新しいモーションを足すとき（ざっくり）

1. `presentation/motion_patterns/` に `xxx_motion.dart` を追加
2. `application/motion_state.dart` に ID やフラグを追加（パターン名付き bool の乱立は避ける）
3. `motion_page.dart` にカードを 1 枚追加
4. `MainShell` の重ね層と `overlayMain()` で表示を切り替え（共通化すると安全）
5. ON/OFF 時は `MotionBackgroundController` の呼び出しを **1 か所にまとめる**

詳細な手順・不変条件・チェックリストは次を参照してください。

- `[docs/share/rt/モーション機能_エージェント向け実装参照.md](../../../docs/share/rt/モーション機能_エージェント向け実装参照.md)`

---

## 用語メモ


| 用語         | 意味                                                           |
| ---------- | ------------------------------------------------------------ |
| シェル（Shell） | `MainShell` の `IndexedStack` + その上のモーション重ね層                  |
| FGS        | Android のフォアグラウンドサービス（通知付きでプロセス継続）                           |
| システムオーバーレイ | 他アプリの上に Flutter UI を載せる Android 機能（`flutter_overlay_window`） |


