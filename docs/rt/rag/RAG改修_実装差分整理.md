# RAG改修 実装差分整理

作成日: 2026-05-29

## 目的

RAG改修で発生した差分を、レビューしやすい単位に整理する。
今回の変更は維持する方針とし、どの差分がRAG本体で、どの差分が検証やフォールバックのための周辺調整かを明確にする。

## RAG本体の差分

### Flutter側

- `lib/features/fb/infrastructure/payload/sleep_payload.dart`
  - RAG APIへ送る安定payload契約を追加。
  - `payload_version`、`sleep_data_source`、`sessions`、`epochs`、`notes`、`target_session_id` を扱う。
- `lib/features/fb/infrastructure/payload/sleep_payload_builder.dart`
  - `SleepRepository` から対象セッションと直近セッションを取得し、RAG用payloadへ変換。
- `lib/features/fb/infrastructure/api/rag_analyze_client.dart`
  - Python backend の `POST /rag_analyze` を呼ぶHTTPクライアントを追加。
- `lib/features/fb/presentation/pages/fb_dashboard_page.dart`
  - 通常アドバイスと特化型アドバイスを `RagAnalyzeClient.analyze()` 経由に差し替え。
  - RAG用のversion付きキャッシュキーへ変更。
- `lib/features/fb/presentation/dialogs/fb_chat_dialog.dart`
  - チャット送信を `RagAnalyzeClient.analyze()` 経由に差し替え。
  - 既存UIとチャット履歴保存の流れは維持。
- `lib/features/fb/domain/features/analysis_result.dart`
  - `/rag_analyze` の `text`、`confidence`、`created_at` に対応。
  - 旧形式の `answer`、`score` も後方互換として許容。
- `lib/features/fb/application/config/analysis_config.dart.example`
  - `RAG_BACKEND_BASE_URL` の設定例を追加。

### Python backend側

- `lib/features/fb/backend/main.py`
  - FastAPI backend として `/health` と `/rag_analyze` を追加。
  - 睡眠要約、商品PDF検索、プロンプト構築、Gemini呼び出しを統合。
- `lib/features/fb/backend/services/sleep_summarizer.py`
  - Flutterから受け取った `sleep_data` を要約文字列へ変換。
- `lib/features/fb/backend/services/product_pdf_loader.py`
  - `data/products/*.pdf` を一次ソースとして読み込む。
  - PDF未配置時は空候補で継続。
- `lib/features/fb/backend/services/product_retriever.py`
  - 依存追加を抑えたキーワード検索で商品候補を抽出。
- `lib/features/fb/backend/services/prompt_builder.py`
  - プロンプトJSONを読み込み、テンプレート変数を注入。
- `lib/features/fb/backend/services/gemini_client.py`
  - Python backendからGemini REST APIを呼び出す。
- `lib/features/fb/backend/prompts/fb_prompts.json`
  - advice typeごとのsystem promptとuser templateをコード外へ分離。
- `lib/features/fb/backend/requirements.txt`
  - FastAPI backend実行に必要なPython依存を明示。

## RAG範囲外だが残す差分

### `lib/features/alarm/infrastructure/sleep_repository.dart`

RAG仕様の「SQLite優先、SQLite不可時は既存参照へフォールバック」を満たすために変更。
RAG payload生成は `SleepRepository` を境界として使うため、ここで `sleep_data_source` を判別できるようにした。

主な内容:

- SQLite初期化・読み込み失敗時にSharedPreferences復元へ継続。
- SQLite書き込み・削除失敗時もSharedPreferences側の永続化を継続。
- `dataSource` getterを追加し、RAG APIへ `sqlite` または `existing_repository_fallback` を送れるようにした。

### `lib/features/alarm/presentation/alarm_page.dart`

RAG本体ではなく、`flutter test` 実行時の既存smoke test安定化のための変更。
テスト環境では `flutter_local_notifications` のプラットフォーム実装が未初期化で例外になるため、通知初期化失敗時に画面構築を止めないようにした。

### `test/widget_test.dart`

RAG本体ではなく、既存smoke test安定化のための変更。
継続アニメーション等により `pumpAndSettle()` がタイムアウトするため、タブ遷移確認に必要な固定時間の `pump` に変更した。

## 整形差分

`dart format lib/features/fb` を一度広めに実行したため、RAG本体ではないFB配下の既存ファイルにも整形のみの差分が発生している。
今回は変更を維持する方針。

整形のみの代表例:

- `lib/features/fb/application/state/analysis_state.dart`
- `lib/features/fb/application/types/analysis_error_type.dart`
- `lib/features/fb/application/types/analysis_params.dart`
- `lib/features/fb/application/types/analysis_status.dart`
- `lib/features/fb/application/usecases/analyze_chat_usecase.dart`
- `lib/features/fb/domain/features/sleep_data.dart`
- `lib/features/fb/domain/types/chat_role.dart`
- `lib/features/fb/infrastructure/api/api_client.dart`
- `lib/features/fb/infrastructure/api/sleep_mock_data.dart`
- `lib/features/fb/infrastructure/log/app_logger.dart`
- `lib/features/fb/presentation/router/fb_router.dart`
- `lib/features/fb/presentation/theme/fb_colors.dart`

## ローカル設定差分

`lib/features/fb/application/config/analysis_config.dart` は `.gitignore` 対象のローカル設定ファイル。
RAG backend URLを参照できるよう `ragBackendBaseUrl` を追加した。
このファイルはコミット対象ではない想定。

## 検証状況

- `dart format` 実行済み。
- `flutter analyze` 成功。
- `flutter test` 成功。
- `py -m compileall lib/features/fb/backend` 成功。
- `py -m pip install -r lib/features/fb/backend/requirements.txt` 実行済み。
- FastAPI app import確認成功。
- `/health` smoke test成功。
- `uvicorn lib.features.fb.backend.main:app --host 127.0.0.1 --port 8000` でbackend起動成功。
- `POST /rag_analyze` smoke test成功。
  - 最小の睡眠payload、`advice_type: chat`、商品PDF未配置の状態でHTTP 200を確認。
  - レスポンスは `text`、`confidence`、`created_at` を返却。
  - PowerShell表示上は日本語本文が文字化けする場合があるため、ASCIIエスケープ出力でも内容を確認済み。
- 商品PDF配置先を `data/products/` に統一済み。
  - `寝具商品カタログ.pdf` と `食品商品カタログ.pdf` の2件を読み込み確認。
  - 寝具クエリでPDF由来の商品候補が検索され、`/rag_analyze` の応答に商品名・メーカー・価格が含まれることを確認。

## 次の疎通確認

Flutterアプリから `RAG_BACKEND_BASE_URL` 経由でbackendへ到達できることを確認する。
商品PDFを追加した後は、`data/products/*.pdf` の検索候補がプロンプトへ入ることを確認する。
