# lib/ 直下フォルダ概要（全体）

対象: `smf_app/lib/` 直下  
目的: `lib/` の構成と、各フォルダの役割・記述内容（現状）を俯瞰できるようにする

## 全体構成（lib/ 直下）

- `main.dart`
- `app/`
- `common/`
- `features/`

## `main.dart`

- **役割**: アプリのエントリポイント。`runApp()` で `SmfApp` を起動する。
- **主な内容**:
  - `package:smf_app/app/main.dart` の `SmfApp` を呼び出すだけの薄い起動ファイル。

## `app/`

- **役割**: アプリ全体（シェル）を組み立てる層。`common/` の共通部品と `features/` の画面（presentation）を結線する。
- **主な内容**:
  - `lib/app/main.dart`
    - `SmfApp`: `MaterialApp` の定義（テーマ、home 等）。
    - `MainShell`: タブ切り替えを持つメイン画面の「シェル」。
      - `common/navigation/MainTabIndexNotifier`（タブ状態）を購読し、`IndexedStack` で各タブ画面を表示。
      - `common/ui/navigation/AppBottomNavigationBar`（見た目）にタブ操作を委譲。
      - 各タブの中身は `features/*/presentation/*` から画面を読み込む（例: `AlarmPage`, `GraphPage`）。

## `common/`

- **役割**: 機能を跨いで使う「共通のUI部品」「UI状態（ナビゲーション等）」を置く。特定機能（ドメイン）に依存しない。
- **主な内容（現状）**:
  - `lib/common/navigation/main_tab_index_notifier.dart`
    - `MainTabIndexNotifier`: メインシェルのタブ選択状態（UI状態のみ）を管理する `ChangeNotifier`。
  - `lib/common/ui/navigation/app_bottom_navigation_bar.dart`
    - `AppBottomNavigationBar`: 下部ナビゲーションバー（表示・スタイル）を提供する Widget。
    - 画面遷移/状態は持たず、`currentIndex` と `onDestinationSelected` を受け取る。
  - `lib/common/test.dart`
    - **現状**: 空（プレースホルダー）。

## `features/`

- **役割**: 機能単位のコード置き場。各機能は原則として層（レイヤ）で分割する構成になっている。
- **レイヤ構成（共通の意図）**:
  - `application/`: ユースケース・アプリケーションサービス（画面から呼ばれる「やること」の実装）
  - `domain/`: エンティティ/値オブジェクト/ドメインサービス等（ビジネスルール）
  - `infrastructure/`: 外部I/O（API、DB、端末機能等）やリポジトリ実装
  - `presentation/`: 画面・Widget（UI）
  - ※現時点では `application/`・`domain/`・`infrastructure/` は `.gitkeep` のみの機能が多く、UI先行で実装が進んでいる。

### `features/alarm/`

- **役割**: アラーム機能。
- **主な内容（現状）**:
  - `presentation/alarm_page.dart`
    - 参考UIに近い「アラーム設定画面（見た目）」を実装。
    - 時刻ピッカー（ホイール）、STARTボタン、右側アクションボタン群等。
    - 計測・通知などの実処理は未実装（UIモック）。

### `features/graph/`

- **役割**: グラフ機能（睡眠記録閲覧）。
- **主な内容（現状）**:
  - `presentation/graph_page.dart`
    - 背景色やタブ等を含むグラフ画面UI。
    - `CustomPaint` で睡眠深度のエリアチャートを描画（`SleepDepthAreaChartPainter`）。
    - 現フェーズは UI のみ（Android 実測データ連携は未実装）。
  - `daily_sleep_depth_mock.dart`
    - グラフ表示用のダミーデータ（固定モック）を生成。
    - `DailySleepDepthMock` / `SleepDepthPoint` / `SleepSummaryMock` などUI表示に必要な最小モデルを保持。

### `features/fb/`

- **役割**: FB（名称から推測。フィードバック/FB連携等の可能性）機能の置き場。
- **主な内容（現状）**:
  - 各レイヤに `.gitkeep` があるのみ（実装は未着手/これから）。

### `features/motion/`

- **役割**: モーション機能（ナビ上「モーション」タブに対応）置き場。
- **主な内容（現状）**:
  - 各レイヤに `.gitkeep` があるのみ（実装は未着手/これから）。

## 現状のまとめ（読み方）

- `app/` が **画面の組み立て（シェル）**、`common/` が **共通部品・共通UI状態**、`features/` が **機能ごとの実装**。
- `features/*` はレイヤ分割の箱が先に用意されており、現状は `presentation/`（UI）中心で実装が進んでいる。

