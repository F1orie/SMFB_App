# 睡眠データの SQLite 移行について

**作成日:** 2026-05-27
**対象フィーチャー:** `lib/features/alarm/`
**ステータス:** 対応予定（優先対応）

---

## 概要

alarm フィーチャーで行っている睡眠データの保存先を、**SharedPreferences から SQLite に移行します。**

現在は `sleep_sessions` / `sleep_epochs` / `sleep_notes` の 3 種類のデータを SharedPreferences に JSON 配列で保存していますが、加速度センサーの時系列データ（`sleep_epochs`）が蓄積されるにつれて読み取りが重くなる問題があります。SQLite に移行することで、必要なデータだけを効率よく取得できるようになります。

---

## 変更の全体像

| 変更種別 | 内容 |
|---|---|
| 新設 | SQLite DB 初期化クラス・SQLite リポジトリ実装・既存データ移行処理 |
| 修正 | `SleepRepository` の実装クラスを SQLite 版に差し替え |
| 変更なし | `SleepRepository` のインターフェース（公開メソッドの名前・引数・戻り値） |
| 変更なし | alarm フィーチャーのUI・記録ロジック・グラフ表示 |

---

## 影響範囲

### 影響しない箇所

`SleepRepository` のインターフェースは変更しません。
以下のメソッドシグネチャはそのまま維持されます。

```dart
Future<void>             saveSession(SleepSession session);
Future<void>             saveEpochs(List<SleepEpoch> epochs);
Future<void>             saveNote(SleepNote note);
Future<List<SleepSession>> getSessions();
Future<List<SleepEpoch>>   getEpochsBySessionId(String sessionId);
Future<SleepNote?>         getNotesBySessionId(String sessionId);
Future<void>             removeSession(String sessionId);
Future<void>             clearAll();
```

`SleepRepository` を呼び出している箇所はコードの修正が不要です。

### 影響する箇所（対応が必要なケース）

`SleepRepository` の **インスタンスを生成・注入している箇所** は、SQLite 版の実装クラスに差し替える必要があります。DI（依存注入）の初期化コードを確認してください。

---

## 新設ファイル

```
features/alarm/infrastructure/
  db/
    sleep_database.dart             # SQLite DB の初期化・テーブル定義
    sleep_sqlite_repository.dart    # SleepRepository の SQLite 実装
  migration/
    shared_prefs_to_sqlite.dart     # 既存データの一回限りの移行処理
```

### sleep_database.dart

sqflite で DB を初期化し、以下の 3 テーブルを作成します。

| テーブル | 内容 |
|---|---|
| `sleep_sessions` | セッション情報（就寝・起床時刻、ステータス等） |
| `sleep_epochs` | 加速度センサーの時系列データ（体動量・睡眠深度スコア） |
| `sleep_notes` | ライフスタイル記録（メモ・飲酒・カフェイン・運動） |

テーブルの詳細なカラム定義は [データベース移行仕様](../rt/rag/データベース移行仕様.md) を参照してください。

### sleep_sqlite_repository.dart

既存の `SleepRepository`（SharedPreferences 実装）と同じインターフェースを SQLite で実装したクラスです。

### shared_prefs_to_sqlite.dart

アプリ起動時に **一度だけ** 実行される移行処理です。移行済みの場合は何もしません。

```
起動時に確認
  └─ 移行済みフラグあり → スキップ
  └─ 移行済みフラグなし
       → SharedPreferences から全データを読み取り
       → SQLite に INSERT
       → 移行済みフラグを書き込み
```

---

## 修正ファイル

| ファイル | 変更内容 |
|---|---|
| `features/alarm/infrastructure/sleep_repository.dart` | SharedPreferences 実装を SQLite 実装に差し替え |
| `main.dart`（DI 初期化箇所） | アプリ起動時に移行処理を呼び出す処理を追加 |

---

## ユーザーデータへの影響

- 既存ユーザーのデータは**失われません**。移行処理で SharedPreferences から SQLite に自動的に引き越されます。
- 移行後も SharedPreferences のデータはすぐには削除しません（確認後に削除予定）。

---

## 関連ドキュメント

- [データベース移行仕様](../rt/rag/データベース移行仕様.md) — テーブル定義・フィールド詳細・ダミーデータ仕様
- [RAGシステム導入 変更仕様書](../rt/rag/rag_system_spec.md) — 本移行が必要になった背景・全体方針
