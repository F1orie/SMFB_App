# RAGシステム 実装概要と処理フロー

作成日: 2026-05-29

## 目的

このドキュメントは、RAG改修後のFB機能を初めて読む人が、全体像、主要ファイル、処理フローを把握できるようにまとめたものです。

セットアップや実行方法は `RAGシステム_セットアップ手順.md` を参照してください。

## 何が変わったか

従来のFB機能は、FlutterアプリからGemini APIを直接呼び出していました。

今回の改修では、AI処理をPython FastAPI backendへ移し、Flutterは睡眠データをRAG用payloadに整形してbackendへ送る構成にしました。

```text
変更前:
Flutter
  └─ Gemini APIを直接呼び出す

変更後:
Flutter
  └─ Python FastAPI backend
       ├─ 睡眠データを要約
       ├─ 商品PDFを検索
       ├─ プロンプトを組み立て
       └─ Gemini APIを呼び出す
```

## 全体フロー

```text
FB画面
  ↓
SleepPayloadBuilder
  ↓
SleepRepository
  ├─ SQLite優先
  └─ SharedPreferencesフォールバック
  ↓
RagAnalyzeClient
  ↓ POST /rag_analyze
Python FastAPI backend
  ├─ sleep_summarizer.py
  ├─ product_pdf_loader.py
  ├─ product_retriever.py
  ├─ prompt_builder.py
  └─ gemini_client.py
  ↓
Gemini API
  ↓
RAG応答
  ↓
Flutter UIへ表示
```

## Flutter側の責務

Flutter側は、UI表示と睡眠データpayloadの作成、backendへのHTTP送信を担当します。

Python backendやGemini APIの詳細は、Flutter側では扱いません。

### `FbDashboardPage`

ファイル:

```text
lib/features/fb/presentation/pages/fb_dashboard_page.dart
```

役割:

- FB画面本体。
- 通常アドバイスを取得する。
- `寝具`、`食べ物`、`ルーティン` の特化型アドバイスを取得する。
- 既存UIレイアウトは維持し、AI通信だけRAG backend呼び出しへ差し替えている。

主な流れ:

```text
画面表示
  ↓
対象SleepSessionを決定
  ↓
SleepPayloadBuilder.build(targetSession)
  ↓
RagAnalyzeClient.analyze(...)
  ↓
応答テキストを画面に表示
```

### `FbChatDialog`

ファイル:

```text
lib/features/fb/presentation/dialogs/fb_chat_dialog.dart
```

役割:

- FB画面から開くチャットUI。
- ユーザーの質問、チャット履歴、対象睡眠データをbackendへ送る。
- 応答をチャット吹き出しに表示する。

### `SleepPayload`

ファイル:

```text
lib/features/fb/infrastructure/payload/sleep_payload.dart
```

役割:

- RAG APIへ送る睡眠データの安定したJSON契約。
- SQLiteのテーブル名やカラム名にPython backendを依存させないための境界。

主な項目:

- `payloadVersion`
- `sleepDataSource`
- `sessions`
- `epochs`
- `notes`
- `targetSessionId`

### `SleepPayloadBuilder`

ファイル:

```text
lib/features/fb/infrastructure/payload/sleep_payload_builder.dart
```

役割:

- `SleepRepository` から睡眠データを取得する。
- 対象セッションと直近セッションをまとめてRAG用payloadに変換する。
- 現在は最大7セッションを含める。

取得するデータ:

- `SleepSession`
- `SleepEpoch`
- `SleepNote`

### `RagAnalyzeClient`

ファイル:

```text
lib/features/fb/infrastructure/api/rag_analyze_client.dart
```

役割:

- Python backendの `POST /rag_analyze` を呼び出すHTTPクライアント。
- Flutter側のAI通信の入口。
- レスポンスを `AnalysisResult` に変換する。

送信する主なJSON:

```json
{
  "query": "ユーザーの質問または分析依頼",
  "advice_type": "bedding | food | routine | chat",
  "payload_version": "1.0",
  "sleep_data_source": "sqlite | existing_repository_fallback",
  "sleep_data": {
    "target_session_id": "...",
    "sessions": [],
    "epochs": [],
    "notes": []
  },
  "chat_history": []
}
```

## 睡眠データの参照元

RAGの睡眠データは、Python backendが直接SQLiteを読むのではありません。

Flutter側の `SleepRepository` が保存済み睡眠データを読み取り、`SleepPayloadBuilder` がRAG用payloadに変換します。

ファイル:

```text
lib/features/alarm/infrastructure/sleep_repository.dart
```

参照順:

```text
非Web環境
  ↓
SQLiteを初期化して読み込み
  ↓ 成功してデータあり
sleep_data_source = sqlite

SQLite失敗またはデータなし
  ↓
SharedPreferencesから復元
  ↓
sleep_data_source = existing_repository_fallback
```

RAG APIへ送る時点では、DBの生スキーマではなく、`SleepPayload` のJSON形式に変換されています。

## Python backend側の責務

Python backendは、RAG処理とGemini API呼び出しを担当します。

### `main.py`

ファイル:

```text
lib/features/fb/backend/main.py
```

役割:

- FastAPIアプリ本体。
- `/health` を提供する。
- `/rag_analyze` を提供する。
- 睡眠要約、商品PDF検索、プロンプト生成、Gemini呼び出しをつなぐ。

主なエンドポイント:

```text
GET /health
POST /rag_analyze
```

### `sleep_summarizer.py`

ファイル:

```text
lib/features/fb/backend/services/sleep_summarizer.py
```

役割:

- Flutterから受け取った `sleep_data` を文章要約に変換する。
- セッション情報、睡眠深度、体動、メモ、飲酒/カフェイン/運動フラグを要約する。

出力例:

```text
データソース: sqlite
対象セッション: 開始=..., 終了=..., 睡眠時間=...
睡眠深度データ: 84件, 平均深度=...
ライフスタイル記録: カフェインあり, メモ=...
```

### `product_pdf_loader.py`

ファイル:

```text
lib/features/fb/backend/services/product_pdf_loader.py
```

役割:

- `data/products/*.pdf` を読み込む。
- `pypdf` でPDFからテキストを抽出する。
- 読み込んだPDFはキャッシュされる。

注意:

- PDFを追加・差し替えた場合はbackend再起動が必要。
- 画像だけのPDFだとテキスト抽出できない可能性がある。

### `product_retriever.py`

ファイル:

```text
lib/features/fb/backend/services/product_retriever.py
```

役割:

- PDFから抽出したテキストを簡易キーワード検索する。
- `advice_type` に応じて検索キーワードを補う。
- 検索結果をプロンプトに入れやすい文字列へ整形する。

現在の検索方式:

- embeddingやChromaは使わない。
- PDF本文に対するキーワード出現数で簡易スコアリングする。

### `prompt_builder.py`

ファイル:

```text
lib/features/fb/backend/services/prompt_builder.py
```

役割:

- `fb_prompts.json` を読み込む。
- `advice_type` に応じたsystem promptとuser templateを選ぶ。
- 睡眠要約、商品候補、ユーザー質問、チャット履歴をテンプレートへ埋め込む。

### `fb_prompts.json`

ファイル:

```text
lib/features/fb/backend/prompts/fb_prompts.json
```

役割:

- プロンプトをコードから分離して管理する。
- `bedding_advice`、`food_advice`、`routine_advice`、`chat` のプロンプトを定義する。

主なテンプレート変数:

- `{sleep_summary}`
- `{product_suggestions}`
- `{query}`
- `{chat_history}`

### `gemini_client.py`

ファイル:

```text
lib/features/fb/backend/services/gemini_client.py
```

役割:

- Gemini REST APIを呼び出す。
- `GEMINI_API_KEY` または `GOOGLE_API_KEY` を環境変数から読む。
- Gemini応答のテキストを取り出し、簡易Markdown除去を行う。

## 商品PDFの参照元

商品PDFは次の場所に置きます。

```text
data/products/
  寝具商品カタログ.pdf
  食品商品カタログ.pdf
```

確認済みのRAG応答例:

- `オルソピロー 整体師監修 頸椎サポート枕`
- `メディカルスリープ研究所`
- `¥18,000`
- `スリープマスター プレミアム低反発枕`
- `ナイトウェル株式会社`
- `¥12,800`

## API契約

### Request

```json
{
  "query": "この睡眠データに基づいた具体的なおすすめ情報を教えてください。",
  "advice_type": "bedding",
  "payload_version": "1.0",
  "sleep_data_source": "sqlite",
  "sleep_data": {
    "target_session_id": "session_xxx",
    "sessions": [],
    "epochs": [],
    "notes": []
  },
  "chat_history": [
    {
      "role": "user",
      "content": "もっと深く寝るには？"
    }
  ]
}
```

### Response

```json
{
  "text": "生成されたアドバイス本文",
  "confidence": 0.75,
  "created_at": "2026-05-29T02:32:15.846439+00:00"
}
```

## 実行時に必要なもの

RAG機能を動かすには、Flutterアプリとは別にPython backendを起動します。

```powershell
$env:GEMINI_API_KEY = "Gemini APIキー"
py -m uvicorn lib.features.fb.backend.main:app --host 127.0.0.1 --port 8000
```

Androidエミュレーターから確認する場合:

```powershell
flutter run -d emulator-5554 --dart-define=RAG_BACKEND_BASE_URL=http://10.0.2.2:8000
```

実行先ごとの詳細は `RAGシステム_セットアップ手順.md` を参照してください。

## キャッシュ

RAG化前のGemini直呼びキャッシュと混ざらないよう、RAG用のversion付きキーを使います。

通常アドバイス:

```text
fb_rag_ai_advice_<payloadVersion>_<sessionId>
```

特化型アドバイス:

```text
fb_rag_special_<payloadVersion>_<type>_<sessionId>
```

チャット履歴:

```text
fb_chat_history_<sessionId>
```

## 初めて読む人向けの見方

まず全体を追う場合は、次の順で読むと理解しやすいです。

1. `fb_dashboard_page.dart`
   - どのタイミングでRAG APIを呼ぶかを見る。
2. `sleep_payload_builder.dart`
   - 睡眠データをどうpayload化しているかを見る。
3. `rag_analyze_client.dart`
   - FlutterからbackendへどんなJSONを送るかを見る。
4. `backend/main.py`
   - backend側で何を順番に呼ぶかを見る。
5. `sleep_summarizer.py`
   - 睡眠データをどう要約しているかを見る。
6. `product_pdf_loader.py` / `product_retriever.py`
   - PDFをどう読み、どう検索しているかを見る。
7. `fb_prompts.json`
   - 最終的にGeminiへ渡るプロンプトの形を見る。

## 現在の制約

- 商品検索は簡易キーワード検索。
- PDFの表崩れや途中改行はある程度そのままLLMに渡る。
- PDF追加後はbackend再起動が必要。
- Python backendはローカル起動前提。
- 本番運用する場合は、HTTPS化、APIキー管理、backend常駐化、ログ管理が別途必要。
