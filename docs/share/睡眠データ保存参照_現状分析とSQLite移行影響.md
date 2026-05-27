# 睡眠データ保存参照 現状分析とSQLite移行影響

対象: `smf_app/lib/` 全体のうち、睡眠データの作成・保存・参照・表示・派生データに関わる実装  
目的: 睡眠データの保存先をSQLiteへ集約する前に、現状のデータ構造、保存場所、参照経路、機能別の責務、修正影響を共有する

## 結論

現状の睡眠データ本体は、`lib/features/alarm/infrastructure/sleep_repository.dart` の `SleepRepository` が `SharedPreferences` に保存しています。

保存される中心データは次の3種類です。

- `SleepSession`: 睡眠1回分の開始・終了・アラーム時刻など
- `SleepEpoch`: 睡眠中の時系列サンプル。活動量と睡眠深度スコアを持つ
- `SleepNote`: 睡眠メモと、アルコール・カフェイン・運動の行動フラグ

アラーム機能がデータを作り、グラフ・リスト・FB機能が `SleepRepository.instance` を直接参照しています。状態管理やDB層はまだなく、起動時に `SharedPreferences` から全件をメモリリストへ読み込み、その後は各画面が同期アクセサで読む構成です。

SQLiteへ移行する場合、単に保存先を差し替えるだけではなく、次の点を合わせて整理する必要があります。

- `SleepRepository` の責務をSQLite中心に変更する。
- `allSessions` / `epochsForSession()` / `notesForSession()` の同期参照前提を見直す。
- アラーム停止時の `session + epochs + note` 保存をトランザクション化する。
- グラフ・リスト・FBがDBから最新状態を再取得できるようにする。
- `SleepNote` とグラフの `action_selections` の二重管理を解消する。
- FBのAIキャッシュやチャット履歴を、睡眠セッション削除やメモ変更に追従させる。

## 現在の保存方式

### 保存先

現在はSQLiteではなく `SharedPreferences` です。

`SleepRepository` は内部に次のメモリリストを持ちます。

```text
_sessions: List<SleepSession>
_epochs:   List<SleepEpoch>
_notes:    List<SleepNote>
```

アプリ起動時に `lib/main.dart` で `await SleepRepository.instance.init()` が呼ばれ、`SharedPreferences` から3種類のデータを読み込んでメモリへ復元します。

### 保存キー

| キー | 保存内容 | 形式 |
| --- | --- | --- |
| `sleep_sessions` | `SleepSession` 一覧 | JSON文字列の `StringList` |
| `sleep_epochs` | `SleepEpoch` 一覧 | JSON文字列の `StringList` |
| `sleep_notes` | `SleepNote` 一覧 | JSON文字列の `StringList` |

睡眠データ本体ではありませんが、睡眠セッションに紐づく派生データとして次のキーもあります。

| キー | 保存内容 | 管理箇所 |
| --- | --- | --- |
| `action_selections` | グラフ画面の行動選択。日付キーから選択行動リストへのJSON | `GraphPage` |
| `fb_ai_advice_<sessionId>` | FB通常AIアドバイス | `FbDashboardPage` |
| `fb_special_<type>_<sessionId>` | FB特化型AIアドバイス | `FbDashboardPage` |
| `fb_chat_history_<sessionId>` | FBチャット履歴 | `FbChatDialog` |

## データモデル

### SleepSession

ファイル: `lib/features/alarm/domain/sleep_session.dart`

睡眠1回分の単位です。

| フィールド | 意味 |
| --- | --- |
| `id` | セッションID。実記録は `session_<epochMs>`、ダミーは `dummy_yyyymmdd` |
| `startAtEpochMs` | 記録開始時刻 |
| `endAtEpochMs` | 記録終了時刻。記録中は `null` |
| `alarmTimeEpochMs` | 設定した起床アラーム時刻 |
| `status` | `recording` または `finished` |
| `algoVersion` | 睡眠深度算出アルゴリズムのバージョン |
| `samplingPeriodSec` | サンプリング周期 |
| `tzOffsetMin` | タイムゾーンオフセット |
| `appVersion` | アプリバージョン |
| `syncState` | 同期状態。現状は `local_only` |

SQLiteでは `sleep_sessions` テーブルの親レコードになる想定です。

### SleepEpoch

ファイル: `lib/features/alarm/domain/sleep_epoch.dart`

睡眠中の時系列データです。

| フィールド | 意味 |
| --- | --- |
| `sessionId` | 所属する `SleepSession.id` |
| `tEpochMs` | サンプル時刻 |
| `activityCount` | 活動量。現状はモック値 |
| `scoreDepth` | 睡眠深度スコア。0.0から1.0 |

グラフ画面は `scoreDepth` を使ってチャートを描画します。FB分析では現状使われていません。

SQLiteでは `sleep_epochs` テーブルとして、`session_id` と `t_epoch_ms` にインデックスを張るのが自然です。

### SleepNote

ファイル: `lib/features/alarm/domain/sleep_note.dart`

睡眠メモと一部の行動フラグです。

| フィールド | 意味 |
| --- | --- |
| `sessionId` | 所属する `SleepSession.id` |
| `createdAtEpochMs` | メモ作成時刻 |
| `memo` | ユーザー入力メモ |
| `hadAlcohol` | アルコール |
| `hadCaffeine` | カフェイン |
| `didExercise` | 運動 |

現状は同じ `sessionId` に複数ノートが保存され得ます。表示側は基本的に `notes.last` を使います。

SQLite移行時には、「1セッション1ノート」にするのか、「履歴として複数ノートを残す」のかを先に決める必要があります。

## データ作成の流れ

### 通常の睡眠記録

関係ファイル:

- `lib/features/alarm/presentation/alarm_page.dart`
- `lib/features/alarm/application/sleep_recorder_service.dart`
- `lib/features/alarm/domain/depth_scoring.dart`
- `lib/features/alarm/domain/sleep_metrics.dart`
- `lib/features/alarm/infrastructure/sleep_repository.dart`

流れ:

1. アラーム画面でSTARTを押す。
2. `SleepRecorderService.start()` が `SleepSession` を作る。
3. セッションIDは `session_<現在epochMs>`。
4. `Timer.periodic` により5秒ごとに仮の `SleepEpoch` が追加される。
5. `activityCount` は `_mockActivityCount()` によるモック値。
6. `scoreDepth` は `DepthScoring.calculateScoreDepth(activityCount)` で算出される。
7. STOPを押す。
8. `SleepRecorderService.stop()` が `finished` 状態の `SleepSession` と `SleepEpoch` 一覧、`SleepMetrics` を返す。
9. `AlarmPage._stopRecording()` が `SleepRepository.instance.saveSession(result.session)` と `saveEpochs(result.epochs)` を呼ぶ。
10. メモダイアログで保存した場合、`SleepRepository.instance.saveNote()` で `SleepNote` を保存する。
11. メモ保存後、FB画面へ遷移する。

注意点:

- 実センサー連携ではなく、現状は動作確認用の仮エポックです。
- `SleepMetrics` は STOP時に算出されますが、現状では保存されません。
- メモをスキップした場合、`SleepNote` は作られません。
- 保存は `session` と `epochs` が先、`note` が後です。SQLite移行後は一連の保存として扱うか検討が必要です。

### ダミーデータ作成

関係ファイル:

- `lib/features/alarm/application/dummy_sleep_data_service.dart`
- `lib/features/alarm/presentation/alarm_page.dart`

`DummySleepDataService.generateAndSave()` は指定日または当日のダミーデータを作成します。

作成内容:

- `SleepSession.id`: `dummy_yyyymmdd`
- `SleepSession.status`: `finished`
- `SleepEpoch`: サイン波ベースの睡眠深度データ
- `SleepNote`: `Demo用ダミーデータ（サイン波生成）` とランダムな行動フラグ

同じ日付で再生成した場合、`saveSession()` は同じIDのセッションを置換し、`removeEpochsForSession()` でエポックも作り直します。ただし `SleepNote` は追加保存なので、古いノートが残り得ます。

## データ保存クラス

### SleepRepository

ファイル: `lib/features/alarm/infrastructure/sleep_repository.dart`

現在の睡眠データ保存・参照の中心です。

主なメソッド:

| メソッド | 内容 |
| --- | --- |
| `init()` | `SharedPreferences` から全データを読み込み、メモリリストを復元 |
| `saveSession()` | 同じIDのセッションを削除してから追加し、全セッションを保存 |
| `saveEpochs()` | エポック一覧を追加し、全エポックを保存 |
| `saveNote()` | ノートを追加し、全ノートを保存 |
| `getSessions()` | 非同期でセッション一覧を返す |
| `getEpochsBySessionId()` | 非同期で指定セッションのエポックを返す |
| `getNotesBySessionId()` | 非同期で指定セッションのノートを返す |
| `allSessions` | 同期アクセサ |
| `epochsForSession()` | 同期アクセサ |
| `notesForSession()` | 同期アクセサ |
| `removeSession()` | 指定セッションを削除 |
| `removeEpochsForSession()` | 指定セッションのエポックを削除 |
| `removeNotesForSession()` | 指定セッションのノートを削除 |
| `clearAll()` | 睡眠データ本体を全削除 |

現在は更新通知を持ちません。`ChangeNotifier`、Stream、Riverpodなどの購読機構はありません。

SQLite移行では、このクラスをDBアクセスの窓口として残すか、別の `SleepDatabase` / `SleepDao` を作って委譲するかを決める必要があります。

## 機能別の参照状況

### アラーム機能

主な役割は睡眠データの作成です。

関係ファイル:

- `lib/features/alarm/presentation/alarm_page.dart`
- `lib/features/alarm/application/sleep_recorder_service.dart`
- `lib/features/alarm/application/dummy_sleep_data_service.dart`
- `lib/features/alarm/domain/*`
- `lib/features/alarm/infrastructure/sleep_repository.dart`

保存するデータ:

- STOP時に `SleepSession`
- STOP時に `SleepEpoch` 一覧
- メモ保存時に `SleepNote`
- ダミーデータ作成時に上記3種類

SQLite移行時の影響:

- STOP時保存は `session`、`epochs`、必要なら `note` を同じDBトランザクションで扱いたい。
- ダミーデータ再生成時の既存ノート削除/更新方針が必要。
- 記録中セッションをDBへ逐次保存するか、STOP時だけ保存するかの判断が必要。
- 実センサー連携を見据えるなら、`SleepEpoch` の保存頻度とバッチ挿入設計が重要。

### グラフ機能

主な役割は睡眠データの表示・メモ編集・行動フラグ編集・削除です。

関係ファイル:

- `lib/features/graph/presentation/graph_page.dart`
- `lib/features/graph/daily_sleep_depth_mock.dart`

表示データの選択順:

1. 2026/4/21 は固定モック `buildMockDailySleepDepth()`
2. 2026/4/22 は固定モック `buildNoSleepMock()`
3. 2026/4/23 は固定モック `buildOversleepMock()`
4. それ以外の日付は `SleepRepository` から対象日のセッションを探す
5. 見つからなければ空モック `buildEmptyMock(date)`

`SleepRepository` から表示する場合:

- 対象日の `SleepSession` を `allSessions.where(...)` で探す。
- 最初の1件 `sessions.first` を使う。
- `epochsForSession(session.id)` で `SleepEpoch` を取得する。
- `SleepEpoch.scoreDepth` を `SleepDepthPoint.depth01` に変換する。
- `notesForSession(session.id).last.memo` をメモとして使う。
- `alarmTimeEpochMs` と `endAtEpochMs` から起床ウィンドウ表示を作る。

グラフ画面の編集:

- メモタブで保存すると、既存ノートを全削除してから新しい `SleepNote` を保存する。
- このとき既存のアルコール・カフェイン・運動フラグは引き継ぐ。
- 行動タブでは `アルコール`、`カフェイン`、`運動` の3つだけ `SleepNote` に書き戻す。
- `食事`、`喫煙`、`入浴` は `action_selections` にのみ保存され、`SleepNote` には入らない。

削除:

- `removeSession(sessionId)`
- `removeEpochsForSession(sessionId)`
- `removeNotesForSession(sessionId)`

削除対象外:

- `action_selections`
- FBのAIアドバイスキャッシュ
- FBチャット履歴

SQLite移行時の影響:

- 固定モック日付が実データより優先される仕様を見直す必要がある。
- 1日に複数セッションがある場合の扱いを決める必要がある。
- 同期アクセサ前提から、非同期DB読み込みまたは購読型に変える必要がある。
- メモと行動フラグの更新は、削除して再作成ではなくUPDATEにするのが自然。
- `action_selections` をSQLiteへ移すか、行動テーブルに統合する必要がある。

### リスト機能

主な役割は保存済み睡眠セッションの一覧表示です。

関係ファイル:

- `lib/features/list/presentation/list_page.dart`

表示方法:

- `initState()` で `SleepRepository.instance.allSessions` をコピーする。
- `startAtEpochMs` の降順で並べる。
- 各カードで `notesForSession(session.id).last` を取得し、メモと行動フラグを表示する。
- カードタップで「グラフを見る」「AI分析を見る」「詳細」を選べる。

注意点:

- `late final List<SleepSession> _sessions` なので、初期表示後に新しい記録が保存されても自動更新されません。
- `IndexedStack` 内で画面が保持されるため、タブ移動だけでは再生成されない可能性があります。

SQLite移行時の影響:

- DBから一覧を再取得する非同期処理が必要。
- 新規記録・削除・メモ編集後に一覧へ反映する通知または再読み込みが必要。
- 一覧に表示するメモは、ノートテーブルとのJOINまたは追加クエリが必要。

### FB機能

主な役割は睡眠データに基づくAI分析・チャットです。

関係ファイル:

- `lib/features/fb/presentation/pages/fb_dashboard_page.dart`
- `lib/features/fb/presentation/dialogs/fb_chat_dialog.dart`
- `lib/features/fb/infrastructure/api/api_client.dart`

参照方法:

- `targetSession` が渡された場合はそれを使う。
- 渡されない場合は `SleepRepository.instance.allSessions.last` を対象にする。
- メモは `notesForSession(session.id).last.memo` を使う。

現状AIプロンプトに使っている情報:

- 就寝時刻
- 起床時刻
- 睡眠時間
- メモ

使っていない情報:

- `SleepEpoch.scoreDepth`
- `SleepEpoch.activityCount`
- `SleepNote.hadAlcohol`
- `SleepNote.hadCaffeine`
- `SleepNote.didExercise`
- グラフ画面の `食事`、`喫煙`、`入浴`

保存している派生データ:

- 通常AIアドバイス: `fb_ai_advice_<sessionId>`
- 特化型アドバイス: `fb_special_<type>_<sessionId>`
- チャット履歴: `fb_chat_history_<sessionId>`

SQLite移行時の影響:

- DBから対象セッション、メモ、エポック、行動フラグを取得する処理が必要。
- AI分析にどのデータを含めるか再設計する余地が大きい。
- メモやエポックが変更された場合、既存AIキャッシュを無効化する仕組みが必要。
- セッション削除時にAIキャッシュやチャット履歴も削除するか決める必要がある。
- チャット履歴をSQLiteに移す場合、`fb_chat_messages` のようなテーブルが必要。

### アプリ起動・画面結線

関係ファイル:

- `lib/main.dart`
- `lib/app/main.dart`

`lib/main.dart` はアプリ起動前に `SleepRepository.instance.init()` を呼びます。SQLite移行後は、ここでDB初期化と旧 `SharedPreferences` からの移行を行う可能性があります。

`lib/app/main.dart` の `MainShell` は、アラーム・グラフ・リスト・FBのタブ間連携を持っています。

- アラームからFBへ: 対象セッションは渡さず、FB側が最新セッションを選ぶ。
- リストからFBへ: `SleepSession` を直接渡す。
- リストからグラフへ: `DateTime` を渡す。

SQLite移行後は、画面間でモデルオブジェクトを渡すより、`sessionId` や日付を渡して遷移先がDBから再取得する方がデータの一貫性を保ちやすくなります。

## 現状の主な問題

### 保存先が複数に分かれている

睡眠データ本体は `SleepRepository`、行動選択の一部は `GraphPage` の `action_selections`、AI関連はFB画面のキーに保存されています。

結果として、セッション削除・メモ変更・行動変更が他の派生データへ完全には伝播しません。

### 同期アクセサ前提

多くの画面が `SleepRepository.instance.allSessions` や `notesForSession()` を同期的に呼んでいます。

SQLiteは基本的に非同期アクセスになるため、現行の呼び出し形をそのまま維持するのは難しいです。メモリキャッシュを残す設計にする場合でも、DBとキャッシュの同期責務を明確にする必要があります。

### 更新通知がない

`SleepRepository` は `ChangeNotifier` や Stream を持たないため、保存・削除後に他画面が自動更新されません。

特に `ListPage` は `initState()` で一度だけ `_sessions` を作るため、保存後の反映に弱いです。

### JSON復元がスキーマ変更に弱い

`fromJson()` は基本的に必須フィールドを直接取り出しています。

フィールド欠損、型変更、古いデータがあると復元時に例外化しやすいです。SQLite移行ではスキーマバージョンとマイグレーション設計が必要です。

### 1日複数セッションへの対応が曖昧

グラフ画面は対象日のセッション一覧から `sessions.first` を使います。

昼寝、二度寝、複数回の記録をどう表示するかは未定義です。

### 行動データが二重管理

`SleepNote` はアルコール・カフェイン・運動だけを持ちます。一方、グラフ画面の行動タブは `食事`、`喫煙`、`入浴` も扱い、これらは `action_selections` にだけ保存されます。

SQLite移行では、行動記録を `SleepNote` に押し込むのではなく、`sleep_actions` のような別テーブルにする方が拡張しやすいです。

### 派生キャッシュの無効化がない

FBアドバイスは `sessionId` 単位でキャッシュされます。

メモ、行動フラグ、エポック、分析ロジックが変わっても、同じ `sessionId` なら古いアドバイスが表示される可能性があります。

## SQLite移行時の想定テーブル

現状データを素直に移すなら、最低限は次の3テーブルです。

```text
sleep_sessions
- id TEXT PRIMARY KEY
- start_at_epoch_ms INTEGER NOT NULL
- end_at_epoch_ms INTEGER
- alarm_time_epoch_ms INTEGER
- status TEXT NOT NULL
- algo_version TEXT NOT NULL
- sampling_period_sec INTEGER NOT NULL
- tz_offset_min INTEGER NOT NULL
- app_version TEXT NOT NULL
- sync_state TEXT NOT NULL

sleep_epochs
- id INTEGER PRIMARY KEY AUTOINCREMENT
- session_id TEXT NOT NULL
- t_epoch_ms INTEGER NOT NULL
- activity_count REAL NOT NULL
- score_depth REAL NOT NULL
- FOREIGN KEY(session_id) REFERENCES sleep_sessions(id) ON DELETE CASCADE

sleep_notes
- id INTEGER PRIMARY KEY AUTOINCREMENT
- session_id TEXT NOT NULL
- created_at_epoch_ms INTEGER NOT NULL
- memo TEXT NOT NULL DEFAULT ''
- had_alcohol INTEGER NOT NULL DEFAULT 0
- had_caffeine INTEGER NOT NULL DEFAULT 0
- did_exercise INTEGER NOT NULL DEFAULT 0
- FOREIGN KEY(session_id) REFERENCES sleep_sessions(id) ON DELETE CASCADE
```

ただし、今後の拡張を考えるなら、行動フラグは別テーブルが望ましいです。

```text
sleep_actions
- id INTEGER PRIMARY KEY AUTOINCREMENT
- session_id TEXT NOT NULL
- action_type TEXT NOT NULL
- created_at_epoch_ms INTEGER NOT NULL
- FOREIGN KEY(session_id) REFERENCES sleep_sessions(id) ON DELETE CASCADE
```

FB関連もSQLiteへ寄せるなら、次のような派生テーブルが候補です。

```text
fb_advice_cache
- id INTEGER PRIMARY KEY AUTOINCREMENT
- session_id TEXT NOT NULL
- advice_type TEXT NOT NULL
- input_hash TEXT NOT NULL
- content TEXT NOT NULL
- created_at_epoch_ms INTEGER NOT NULL

fb_chat_messages
- id INTEGER PRIMARY KEY AUTOINCREMENT
- session_id TEXT NOT NULL
- role TEXT NOT NULL
- content TEXT NOT NULL
- created_at_epoch_ms INTEGER NOT NULL
```

## 移行方針の候補

### 方針A: SleepRepositoryをSQLite実装に置き換える

既存画面の依存先を大きく変えず、`SleepRepository` の内部だけをSQLite化します。

利点:

- 既存コードの変更量を抑えやすい。
- `SleepRepository.instance` という参照先を維持できる。

課題:

- 同期アクセサをどう扱うかが問題。
- DBとメモリキャッシュの二重管理になりやすい。
- 画面更新通知は別途必要。

### 方針B: SleepDatabase / DAOを新設し、画面を非同期参照へ移行する

SQLiteを正式な永続化層として導入し、RepositoryはDAOへ委譲するか、UseCase層からDBを呼びます。

利点:

- SQLiteらしい設計にしやすい。
- クエリ、トランザクション、マイグレーション、テストを整理しやすい。

課題:

- グラフ・リスト・FBなどの呼び出し側修正が大きい。
- 画面ごとのローディング/エラー状態が必要。

### 方針C: DB + Stream/Notifierで購読型にする

DB保存後に各画面が自動更新されるよう、Repositoryに `ChangeNotifier`、Stream、または状態管理ライブラリを導入します。

利点:

- 一覧・グラフ・FBのデータ不整合が減る。
- `IndexedStack` で画面が保持されても更新を反映しやすい。

課題:

- 現在のUIコードには状態購読がほぼないため、導入範囲を決める必要がある。

## 修正対象一覧

SQLite移行で修正が必要になりやすいファイルです。

| ファイル | 修正理由 |
| --- | --- |
| `lib/features/alarm/infrastructure/sleep_repository.dart` | 保存先を `SharedPreferences` からSQLiteへ変更する中心 |
| `lib/main.dart` | DB初期化、旧データ移行、起動順の管理 |
| `lib/features/alarm/presentation/alarm_page.dart` | STOP時保存、メモ保存、遷移後の更新 |
| `lib/features/alarm/application/dummy_sleep_data_service.dart` | ダミーデータ保存、再生成時の上書き方針 |
| `lib/features/graph/presentation/graph_page.dart` | DB参照、メモ更新、行動更新、削除、1日複数セッション対応 |
| `lib/features/list/presentation/list_page.dart` | 一覧の非同期取得、保存/削除後の再読込 |
| `lib/features/fb/presentation/pages/fb_dashboard_page.dart` | セッション・メモ・エポック・行動フラグのDB取得、AIキャッシュ無効化 |
| `lib/features/fb/presentation/dialogs/fb_chat_dialog.dart` | チャット履歴をSQLiteへ寄せる場合に修正 |
| `lib/features/graph/daily_sleep_depth_mock.dart` | DB由来の表示モデルと固定モックの関係整理 |
| `lib/features/fb/domain/features/sleep_data.dart` | グラフ側モデルとの重複整理 |

## 移行時に決めるべき仕様

SQLite実装前に、少なくとも次を決める必要があります。

- 1セッション1ノートか、ノート履歴を残すか。
- 1日に複数セッションがある場合、グラフは合算・選択・最初/最後のどれにするか。
- 行動データを `SleepNote` に残すか、別テーブルへ分離するか。
- `食事`、`喫煙`、`入浴` を正式な睡眠データとして保存するか。
- FBのAIアドバイスとチャット履歴をSQLiteに含めるか、従来通り `SharedPreferences` に残すか。
- セッション削除時に、AIキャッシュ・チャット履歴・行動選択も削除するか。
- 記録中のエポックを逐次DB保存するか、STOP時にまとめて保存するか。
- 旧 `SharedPreferences` データを一度だけSQLiteへ移行するか、開発段階として破棄可能にするか。
- DBスキーマバージョンとマイグレーション方針。

## 推奨される整理順

1. 睡眠データの正をSQLiteにする範囲を決める。
2. `SleepSession`、`SleepEpoch`、`SleepNote`、行動データのテーブル設計を確定する。
3. `SleepRepository` をSQLite対応にするか、新しいDB/DAO層を作るか決める。
4. 旧 `SharedPreferences` からの移行処理を設計する。
5. アラーム停止時の保存をトランザクション化する。
6. グラフ画面をDB由来のデータ表示へ寄せる。
7. リスト画面をDB更新に追従できる形にする。
8. FB分析の入力データとキャッシュ無効化ルールを整理する。
9. 削除時に関連データが残らないようカスケードまたは明示削除を整える。

## 重要な見落としポイント

`pubspec.yaml` にはすでに `sqflite`、`path_provider`、`path` が依存として追加されています。ただし、現行のDart実装ではSQLiteを使っている箇所は確認できません。

つまり、SQLite移行の下準備として依存は入っていますが、実際の保存・参照はまだ `SharedPreferences` とメモリリストです。

また、睡眠データに関わる「正」のデータは現状1つではありません。`SleepRepository` の3モデルを中心にしつつ、グラフの行動選択とFBの派生キャッシュもセッションIDに紐づくため、SQLite移行時には削除・更新・再分析の整合性まで含めて扱う必要があります。
