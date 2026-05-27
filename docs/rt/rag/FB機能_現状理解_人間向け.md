# FB機能 現状理解 人間向け

## 目的

この文書は、`lib/features/fb` 配下を大規模修正する前の現状理解をまとめたものです。
対象は `D:\4_26_f\Solution\smfb_app\lib\features\fb` 配下の全19ファイルです。`.gitignore` 対象のローカル設定ファイル `analysis_config.dart` も、実ファイルとして確認対象に含めています。

変更前の把握を優先し、現在の実動線、各ファイルの責務、使われていない可能性が高い旧設計、保存データ、外部API、修正時の注意点を整理します。

## 全体像

`fb` は「睡眠記録に対するAI分析・フィードバック」機能です。
現在の主なユーザー体験は、睡眠セッションを選び、その就寝時刻・起床時刻・睡眠時間・メモをもとに Gemini API へ問い合わせ、睡眠アドバイスを表示する流れです。

実装上は、設計層がきれいに使い分けられているというより、現在動いている画面実装と、過去に想定されていた UseCase / Repository / Python バックエンド設計が混在しています。

主な実動線は次の通りです。

1. `lib/main.dart` で `SleepRepository.instance.init()` が呼ばれ、保存済みの睡眠セッション・エポック・メモが `SharedPreferences` からメモリへ復元される。
2. `lib/app/main.dart` の `MainShell` が `FbDashboardPage` を下部タブのFB画面として組み込む。
3. `FbDashboardPage` は、指定された `targetSession` があればそれを使い、なければ `SleepRepository.instance.allSessions.last` を対象にする。
4. 対象セッションのメモを `SleepRepository.instance.notesForSession(session.id)` から取得する。
5. 通常アドバイスはメモリキャッシュ、`SharedPreferences`、Gemini API の順で取得する。
6. 寝具・食べ物・ルーティンの特化型アドバイスは、ボタン押下時に `SharedPreferences` のキャッシュを確認し、なければ Gemini API を呼ぶ。
7. チャットは `FbChatDialog` で行い、同じ睡眠セッションの情報を system prompt に含めて Gemini API へ送信する。

## ディレクトリ構成

```text
lib/features/fb
├─ application
│  ├─ config
│  │  ├─ analysis_config.dart
│  │  └─ analysis_config.dart.example
│  ├─ state
│  │  └─ analysis_state.dart
│  ├─ types
│  │  ├─ analysis_error_type.dart
│  │  ├─ analysis_params.dart
│  │  └─ analysis_status.dart
│  └─ usecases
│     └─ analyze_chat_usecase.dart
├─ backend
│  └─ main.py
├─ domain
│  ├─ features
│  │  ├─ analysis_result.dart
│  │  └─ sleep_data.dart
│  └─ types
│     └─ chat_role.dart
├─ infrastructure
│  ├─ api
│  │  ├─ api_client.dart
│  │  ├─ rag_repository.dart
│  │  └─ sleep_mock_data.dart
│  └─ log
│     └─ app_logger.dart
└─ presentation
   ├─ dialogs
   │  └─ fb_chat_dialog.dart
   ├─ pages
   │  └─ fb_dashboard_page.dart
   ├─ router
   │  └─ fb_router.dart
   └─ theme
      └─ fb_colors.dart
```

## 現在の主要な動き

### FBダッシュボード

中心は `presentation/pages/fb_dashboard_page.dart` です。

この画面は `StatefulWidget` で、`SleepSession? targetSession` を受け取れます。`targetSession` がない場合は `SleepRepository.instance.allSessions.last`、つまり最後に保存された睡眠セッションを対象にします。セッションが1件もない場合は「データがありません」と表示します。

対象セッションが見つかった場合は、同じ `session.id` のメモ一覧から最後のメモを取り出します。現在プロンプトに入る睡眠情報は、就寝時刻、起床時刻、睡眠時間、メモのみです。`SleepEpoch` の睡眠深度や活動量、`SleepNote` のアルコール・カフェイン・運動フラグは、現行のFBプロンプトでは使われていません。

通常アドバイスの取得順は次の通りです。

1. static Map `_adviceCache`
2. `SharedPreferences` の `fb_ai_advice_<sessionId>`
3. Gemini API 呼び出し

画面には基本情報カード、通常AIアドバイス、特化型アドバイスボタン、チャット起動ボタンが表示されます。

### 特化型アドバイス

`AdviceType` は `bedding`、`food`、`routine` の3種類です。

各ボタンを押すと、`fb_special_<type>_<sessionId>` というキーで `SharedPreferences` を確認します。保存済みならそれを表示し、なければ種別ごとの system prompt を組み立てて Gemini API を呼びます。

特化型アドバイスの文面は、通常アドバイスより長めの約300文字を想定しています。

### AIチャット

`presentation/dialogs/fb_chat_dialog.dart` がチャット用のボトムシートです。

`FbChatDialog` は `SleepSession` と `memo` を受け取り、system prompt に睡眠情報を埋め込みます。ユーザーの質問と過去履歴を `ApiClient.chat()` に渡し、返答を吹き出しで表示します。

チャット履歴は `SharedPreferences` の `fb_chat_history_<sessionId>` に JSON 文字列として保存されます。

### Gemini API クライアント

`infrastructure/api/api_client.dart` が現在のAI通信の中心です。

モデルは `gemini-2.5-flash` です。エンドポイントは Google Generative Language API の `generateContent` です。APIキーは `AnalysisConfig.geminiApiKey` から取得されます。

送信内容は次の形です。

- `system_instruction.parts[0].text`: system prompt
- `contents`: 履歴と今回のユーザーメッセージ
- `generationConfig.maxOutputTokens`: 1500

HTTP 503 の場合は最大2回リトライします。成功時は最初の `candidates[0].content.parts[0].text` を取り出し、簡単な Markdown 除去を行って返します。

## 各ファイルの責務

### application/config/analysis_config.dart

Gemini APIキーと `alertThreshold` を持つローカル設定ファイルです。

実ファイルにはAPIキーが直接設定されています。値そのものはこの文書には転記しません。`.gitignore` では `lib/features/fb/application/config/analysis_config.dart` が除外対象になっていますが、秘密情報がアプリ側コードに直書きされる構成である点は重要です。

大規模修正時は、環境変数、ビルド時注入、サーバー経由、秘密管理のいずれかに整理する余地があります。

### application/config/analysis_config.dart.example

`analysis_config.dart` の雛形です。

Google AI Studio で取得したAPIキーを `geminiApiKey` に設定する手順がコメントで書かれています。`alertThreshold` は `0.7` です。

### application/state/analysis_state.dart

分析状態を表す単純なクラスです。

`isLoading`、`AnalysisResult? result`、`String? errorMessage` を持ちます。ただし、現在の `FbDashboardPage` や `FbChatDialog` からは使われていません。状態管理を UseCase / State に寄せる構想の名残と見られます。

### application/types/analysis_error_type.dart

`network`、`timeout`、`invalidKey`、`unknown` を持つエラー種別 enum です。

コメントには Python 前提の表現があります。現行のUIや `ApiClient` では使われていません。

### application/types/analysis_params.dart

分析入力を表すクラスです。

`query`、`useHistory`、`maxTokens` を持ちます。現在の実動線では使われていません。

### application/types/analysis_status.dart

`initial`、`loading`、`success`、`failure` を持つ分析状態 enum です。

コメントには「Pythonサーバーに問い合わせ中」とあり、旧設計の名残が見えます。現在の画面では独自の bool state を使っており、この enum は参照されていません。

### application/usecases/analyze_chat_usecase.dart

`RagRepository.fetchAnalysis()` を呼び、戻り値を `AnalysisResult.fromJson()` に変換する UseCase です。

現在の `FbDashboardPage` と `FbChatDialog` は `ApiClient.chat()` を直接呼ぶため、この UseCase は実動線に入っていません。

### backend/main.py

FastAPI + OpenAI SDK を使った別バックエンドです。

`/analyze_sleep` に `efficiency`、`deep_time`、`awakening_count`、`memo` を受け取り、`gpt-4o` で睡眠改善アドバイスを返す実装です。Dart 側からこの Python サーバーを呼ぶコードは、現状の `fb` 配下にはありません。

### domain/features/analysis_result.dart

AI分析結果のドメインモデルです。

`text`、`confidence`、`createdAt` を持ちます。`fromJson()` は `answer` と `score` を期待します。現在は `AnalyzeChatUseCase` 経由でのみ参照され、画面の実動線では使われていません。

### domain/features/sleep_data.dart

睡眠グラフ用のモックデータ構造です。

`SleepDepthPoint`、`SleepSummaryMock`、`DailySleepDepthMock` を定義します。FB画面のAI分析では直接使われていませんが、`infrastructure/api/sleep_mock_data.dart` から参照されています。また、グラフ機能側から `buildMockDailySleepDepth()` が参照されています。

### domain/types/chat_role.dart

チャットのロール enum です。

`user` と `assistant` を持ちます。現在の `FbChatDialog` では enum ではなく `Map<String, String>` の `role` に文字列を入れているため、この enum は使われていません。

### infrastructure/api/api_client.dart

Gemini API クライアントです。

現在のAI分析・特化型アドバイス・AIチャットはすべてこのクラスの `chat()` に集約されています。履歴の `assistant` は Gemini API 用に `model` に変換されます。HTTPクライアントはインスタンスフィールドとして保持されますが、明示的な `close()` はありません。

注意点として、成功レスポンスの `candidates` や `parts` が空の場合の防御はありません。また、catch のリトライ条件が `e is! Exception` になっているため、一般的な `Exception` ではリトライされません。

### infrastructure/api/rag_repository.dart

`ApiClient.chat()` を包む後方互換用 Repository です。

コメントでは「Claude API」とありますが、実際には `ApiClient.chat()` なので Gemini API です。現行画面からは使われていません。

### infrastructure/api/sleep_mock_data.dart

`DailySleepDepthMock` を生成する関数を持つモックデータファイルです。

`buildMockDailySleepDepth()` は `SleepDepthPoint` の波形データと睡眠サマリー、メモを返します。コメントには `buildNoSleepMock()` や `buildOversleepMock()` もここに記述するとありますが、このファイル内にはありません。

現状、グラフ画面側で `buildMockDailySleepDepth()` が参照されています。

### infrastructure/log/app_logger.dart

`dart:developer` を使った簡易ロガーです。

`d()` と `e()` を持ちます。`ApiClient` と `RagRepository` から使われています。

### presentation/dialogs/fb_chat_dialog.dart

AI睡眠アドバイザーのチャットUIです。

履歴読み込み、履歴保存、メッセージ送信、Gemini API 呼び出し、吹き出し表示、タイピング表示をこの1ファイルで持っています。`TextEditingController` と `ScrollController` は `dispose()` されています。

履歴の JSON が壊れている場合、`_loadHistory()` の `jsonDecode()` で例外になる可能性があります。

### presentation/pages/fb_dashboard_page.dart

FB機能の中心画面です。

睡眠データ取得、通常アドバイス取得、特化型アドバイス取得、画面描画、チャット起動をすべて担当しています。現在の機能の多くがここに集中しています。

`ApiClient` は画面内で直接生成されます。通常アドバイスは static Map と `SharedPreferences` にキャッシュされます。特化型アドバイスは `SharedPreferences` にのみ保存されます。

### presentation/router/fb_router.dart

`/fb_dashboard` から `FbDashboardPage` へ遷移するルート定義です。

ただし、現在のアプリ本体は `MaterialApp.routes` にこの `FbRouter.routes` を組み込んでおらず、`MainShell` のタブで `FbDashboardPage` を直接表示しています。

### presentation/theme/fb_colors.dart

FB機能向けの色定義です。

`primaryBlue`、`bgGradient`、`accentPink`、`sleepDeep`、`sleepLight` を持ちます。現在の `FbDashboardPage` と `FbChatDialog` では Flutter 標準の `Colors.blue` などが直接使われており、このクラスは参照されていません。

## 保存データ

`fb` 機能が使う `SharedPreferences` のキーは次の通りです。

| キー | 用途 |
| --- | --- |
| `fb_ai_advice_<sessionId>` | 通常のAI睡眠アドバイス |
| `fb_special_<type>_<sessionId>` | 寝具・食べ物・ルーティンの特化型アドバイス |
| `fb_chat_history_<sessionId>` | セッション単位のチャット履歴 |

睡眠データ本体は `features/alarm` 側の `SleepRepository` に保存されます。

| キー | 用途 |
| --- | --- |
| `sleep_sessions` | 睡眠セッション |
| `sleep_epochs` | 睡眠エポック |
| `sleep_notes` | 睡眠メモ |

## 依存関係

FB機能は主に次に依存しています。

- Flutter Material UI
- `shared_preferences`
- `http`
- `features/alarm/domain/sleep_session.dart`
- `features/alarm/infrastructure/sleep_repository.dart`
- Gemini API

`SleepRepository` から読めるデータには `SleepEpoch` の `scoreDepth` や `activityCount`、`SleepNote` の `hadAlcohol`、`hadCaffeine`、`didExercise` があります。ただし現行のFBプロンプトでは利用されていません。

## 現行設計の特徴

現在のコードは、画面中心の実装です。

`FbDashboardPage` と `FbChatDialog` が `ApiClient` を直接生成して呼び出し、状態も `setState` で管理します。UseCase、Repository、State、Domain Model の一部は存在しますが、現在の主要な画面フローには組み込まれていません。

そのため、大規模修正時は次のどちらに寄せるかを先に決めると整理しやすくなります。

- 画面から `ApiClient` を直接呼ぶ現行構成を前提に、不要な旧設計を削る。
- UseCase / Repository / State / Domain Model を正式な層として復活させ、画面から直接AI通信しない構成に戻す。

## 注意点

APIキーがアプリ内設定ファイルに直書きされています。値は `.gitignore` で除外されていても、端末やビルド成果物には含まれる可能性があります。大規模修正では秘密情報の扱いを見直すべきです。

通常アドバイスのキャッシュは `session.id` 単位です。メモを後から変更しても、同じセッションIDなら古いアドバイスが再利用されます。

チャット履歴は無制限に蓄積されます。履歴が長くなるとプロンプトが肥大化し、API料金やトークン制限に影響します。

`ApiClient` はレスポンス構造に強く依存しています。Gemini API が safety block などで `candidates` を返さない場合、型変換や `first` で例外になる可能性があります。

`backend/main.py` は Dart 側から使われていません。将来サーバー経由にするなら再利用可能ですが、現状の Gemini 直呼び構成とは別系統です。

## テスト観点

現時点で `fb` 専用テストは確認できていません。

大規模修正前後で優先度が高いテスト観点は次の通りです。

- 睡眠セッションがない場合に「データがありません」と表示される。
- `targetSession` が渡された場合、そのセッションを対象にする。
- `targetSession` がない場合、最後の保存済みセッションを対象にする。
- 通常アドバイスがメモリキャッシュ、`SharedPreferences`、API の順で解決される。
- API失敗時にエラー表示と再試行ボタンが出る。
- 特化型アドバイスが種別ごとに別キーでキャッシュされる。
- チャット履歴がセッション単位で保存・復元される。
- Gemini API の成功、HTTPエラー、503リトライ、レスポンス欠損を扱える。

テストしやすくするには、`ApiClient` を直接生成する構成から、差し替え可能な依存として注入できる形に変えるのが有効です。

## 修正前の判断材料

今後の大規模修正では、まず「FB機能をどの方向に育てるか」を決める必要があります。

AIアドバイスを軽量に維持するなら、`FbDashboardPage` と `FbChatDialog` を中心に整理し、未使用の UseCase / Repository / Python バックエンドを削る方向が分かりやすいです。

一方で、睡眠深度、途中覚醒、アルコール、カフェイン、運動、過去履歴、RAG などを本格的に使うなら、UseCase / Repository / Domain Model を再構築し、UIから分析ロジックとAI通信を分離した方が後の変更に耐えやすくなります。
