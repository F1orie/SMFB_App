# RAGシステム導入 変更仕様書

**対象ディレクトリ:** `lib/features/fb/`、`lib/features/alarm/`（SQLite 移行）
**作成日:** 2026-05-27
**ステータス:** 策定中

**関連ドキュメント:**
- [データベース移行仕様](データベース移行仕様.md) — SQLite 移行・テーブル定義・ダミーデータの詳細

---

## 1. 概要

### 目的

現在の AI フィードバック機能（`features/fb/`）に RAG（Retrieval-Augmented Generation）システムを導入し、以下を実現する。

- ユーザーの実際の睡眠データに基づいた、より個人化されたアドバイス
- Chroma に保存された商品データから、具体的な商品名を含む提案

### 方針

| 項目 | 方針 |
|------|------|
| UI | **変更しない**（既存の画面・操作フローを維持） |
| アーキテクチャ | **B案採用**：Python バックエンドが RAG 処理を一元管理 |
| 睡眠データの保存 | SharedPreferences → **SQLite に移行**（`sqflite` は既に依存済み） |
| 睡眠データの取得 | Flutter が SQLite から読み取り、バックエンドに送信 |
| 既存データの移行 | アプリ初回起動時に SharedPreferences → SQLite へ自動マイグレーション |
| 商品提案 | Python バックエンドが Chroma を検索してプロンプトに注入 |
| LLM 呼び出し | Python バックエンドから Gemini を呼び出す（Flutter 直接呼び出しを廃止） |
| プロンプト | Python 側の設定ファイルで管理（コードに直接書かない） |

---

## 2. 現状のデータ構造

alarm フィーチャーの睡眠データは現在 **SharedPreferences（JSON）** で保存されており、SQLite への移行が必要。

テーブル定義・フィールド詳細・ダミーデータ仕様は **[データベース移行仕様](データベース移行仕様.md)** を参照。

| SharedPreferences キー | 内容 |
|---|---|
| `sleep_sessions` | セッション一覧 |
| `sleep_epochs` | 時系列の睡眠深度データ（加速度センサー由来） |
| `sleep_notes` | ライフスタイル記録 |

---

## 3. 変更しない範囲

```
features/fb/presentation/
  pages/fb_dashboard_page.dart     # UI変更なし
  dialogs/fb_chat_dialog.dart      # UI変更なし
  router/fb_router.dart            # 変更なし
  theme/fb_colors.dart             # 変更なし

features/fb/domain/
  features/analysis_result.dart    # 変更なし
  features/sleep_data.dart         # 変更なし
  types/chat_role.dart             # 変更なし
```

---

## 4. SQLite 移行（alarm フィーチャー）

RAG システムの前提となる作業。alarm フィーチャーの保存層のみを入れ替える。
`SleepRepository` のインターフェースは変えないため、上位レイヤーへの影響は最小限。

詳細は **[データベース移行仕様](データベース移行仕様.md)** を参照。

### 新設ファイル（概要）

```
features/alarm/infrastructure/
  db/
    sleep_database.dart              # sqflite DB 初期化・テーブル定義
    sleep_sqlite_repository.dart     # SQLite 実装（Phase 0: 読み取りのみ、Phase 4: 書き込み追加）
  migration/
    shared_prefs_to_sqlite.dart      # 既存データの一回限りの移行処理（Phase 4）
```

### 修正ファイル（alarm フィーチャー）

| ファイル | フェーズ | 変更内容 |
|----------|---------|---------|
| `features/alarm/infrastructure/sleep_repository.dart` | Phase 4 | SQLite 実装クラスに差し替え |
| `main.dart`（DI 初期化箇所） | Phase 4 | マイグレーション処理を呼び出す |

---

## 5. RAG システム構成（B案）

### 全体データフロー

```
UI（変更なし）
  ↓ ユーザー操作（アドバイス種別 + チャット入力）
Flutter
  ├─ SQLite から直近の睡眠データを読み取り（SleepSqliteRepository）
  └─ HTTP POST /rag_analyze へ送信
       { query, advice_type, sleep_data }
          ↓
Python FastAPI（RAGAnalyzeRouter）
  ├─ 1. プロンプト設定ファイルを読み込み（fb_prompts.json）
  ├─ 2. sleep_data から睡眠課題を抽出・要約
  ├─ 3. Chroma へ商品検索クエリを送信 → 関連商品リストを取得
  ├─ 4. プロンプトを組み立て（テンプレート + 睡眠データ + 商品名）
  └─ 5. Gemini API を呼び出し
          ↓
レスポンステキスト（商品名入りアドバイス）
  ↓
Flutter → UI 表示（変更なし）
```

### ポイント

- Gemini の呼び出しは **Python 側に移管**。`api_client.dart` の直接呼び出しは廃止。
- プロンプトの組み立てロジックは **Python 側に集約**。Flutter は SQLite 読み取りと送受信のみを担当。
- Chroma アクセスは Python 内で完結するため、Flutter 側に Chroma 関連の実装は不要。

---

## 6. Python バックエンド 変更内容

### 新設エンドポイント

```
POST /rag_analyze
Request:
  {
    "query": "string",
    "advice_type": "bedding" | "food" | "routine" | "chat",
    "sleep_data": {
      "sessions": [ ...SleepSession の JSON ],
      "epochs":   [ ...SleepEpoch の JSON ],
      "notes":    [ ...SleepNote の JSON ]
    },
    "chat_history": [
      { "role": "user" | "assistant", "content": "string" }
    ]
  }

Response:
  {
    "text": "生成されたアドバイステキスト",
    "confidence": 0.0〜1.0,
    "created_at": "ISO8601"
  }
```

### プロンプト設定ファイル

```
backend/
  prompts/
    fb_prompts.json
```

#### fb_prompts.json 構造（案）

```json
{
  "version": "1.0",
  "prompts": {
    "bedding_advice": {
      "system": "あなたは睡眠と寝具の専門家です。...",
      "user_template": "以下の睡眠データと関連商品を参考に、寝具に関するアドバイスをしてください。\n\n【睡眠データ】\n{sleep_summary}\n\n【おすすめ商品候補】\n{product_suggestions}"
    },
    "food_advice": {
      "system": "あなたは栄養と睡眠の専門家です。...",
      "user_template": "..."
    },
    "routine_advice": {
      "system": "あなたは睡眠習慣の改善を専門とするコーチです。...",
      "user_template": "..."
    },
    "chat": {
      "system": "あなたは睡眠改善アドバイザーです。...",
      "user_template": "{query}"
    }
  }
}
```

#### テンプレート変数

| 変数 | 内容 |
|------|------|
| `{sleep_summary}` | Flutter から受け取った睡眠データの要約文字列 |
| `{product_suggestions}` | Chroma 検索結果の商品名・説明リスト |
| `{query}` | ユーザーの入力テキスト |

### 新設ファイル（Python側）

```
backend/
  routers/
    rag_analyze.py         # POST /rag_analyze エンドポイント
  services/
    sleep_summarizer.py    # 受け取った睡眠データを要約テキストに変換
    chroma_client.py       # Chroma 検索ロジック
    prompt_builder.py      # テンプレートへの変数注入
  prompts/
    fb_prompts.json        # プロンプト設定ファイル
```

### 修正ファイル（Python側）

| ファイル | 変更内容 |
|----------|---------|
| `backend/main.py` | `rag_analyze` ルーターを追加、Chroma クライアント初期化 |

---

## 7. Flutter 側 変更内容（fb フィーチャー）

### 変更方針

Flutter（fb フィーチャー）の責務は以下の 2 点に絞る。

1. alarm フィーチャーの `SleepSqliteRepository` から直近の睡眠データを読み取る
2. Python バックエンドの `/rag_analyze` へ送信し、レスポンスを表示する

### 新設ファイル

```
features/fb/infrastructure/
  api/
    rag_analyze_client.dart    # POST /rag_analyze を呼び出す HTTP クライアント
```

#### インターフェース（案）

```dart
class RagAnalyzeClient {
  Future<AnalysisResult> analyze({
    required String query,
    required String adviceType,
    required SleepPayload sleepData,
    List<ChatMessage> chatHistory = const [],
  });
}
```

### 修正ファイル

| ファイル | 変更内容 |
|----------|---------|
| `infrastructure/api/rag_repository.dart` | `RagAnalyzeClient` を使う実装に差し替え |
| `application/usecases/analyze_chat_usecase.dart` | SQLite から実データを取得して送信するよう変更 |
| `application/config/analysis_config.dart` | バックエンドのエンドポイント URL を追記 |

### 削除（移行完了後）

| ファイル | 理由 |
|----------|------|
| `infrastructure/api/sleep_mock_data.dart` | SQLite 実データに移行後に削除 |
| `infrastructure/api/api_client.dart` | Gemini 直接呼び出しをバックエンドに移管のため削除 |

---

## 8. 未決事項

| # | 事項 | 状態 |
|---|------|------|
| 1 | Chroma のコレクション名・商品データスキーマ | 後から決定 |
| 2 | Chroma embedding モデルの選定 | 後から決定 |
| 3 | バックエンドの URL（開発・本番） | `analysis_config.dart` に追記予定 |
| 4 | プロンプト設定ファイルのバージョン管理方針 | 要検討 |

---

## 9. 作業フェーズ（案）

### 方針

**方針変更（2026-05-27）:** SQLite 移行を優先対応とし、RAG 開発と並行して進める。
DB 移行は別チームと分担するため、先行して完了させる。

```
Phase 0: SQLite 完全移行（alarm フィーチャー）        ← 最優先・先行対応
  【alarm フィーチャー】
  - SleepDatabase 実装（テーブル定義・sqflite 初期化）
  - SleepSqliteRepository 実装（読み取り・書き込み全メソッド）
  - SharedPreferences → SQLite マイグレーション実装
  - alarm フィーチャーの保存先を SQLite に切り替え
  - 既存動作（アラーム・記録・グラフ）への影響がないことを確認
  ※ 共有ドキュメント: docs/share/睡眠データのSQLite移行について.md

  ※ 以下は RAG 開発と並行して進める
Phase 1: プロンプト設定ファイルの整備
  - backend/prompts/fb_prompts.json の作成
  - PromptBuilder の実装（テンプレート変数の注入）

Phase 2: バックエンド RAG エンドポイントの実装
  - SleepSummarizer（受け取った睡眠データを要約テキストに変換）
  - POST /rag_analyze エンドポイント（Chroma なし・モック商品で動作確認）
  - Flutter 側 RagAnalyzeClient の実装と疎通確認
  ✔ この時点で SQLite 実データを使ったアドバイス生成が動作する

Phase 3: Chroma 商品検索の統合
  - ChromaClient の実装
  - 商品データの投入とスキーマ確定
  - エンドポイントへの組み込みと動作確認
  ✔ この時点で RAG システムが完成

Phase 4: クリーンアップ
  - sleep_mock_data.dart の削除
  - api_client.dart の削除（Gemini 直接呼び出しの廃止）
  - SharedPreferences の sleep_* キーを削除するクリーンアップ処理の追加
```
