# RAGシステム セットアップ手順

作成日: 2026-05-29

## 目的

別PCでもRAGシステムを再現できるように、Python backend、Gemini APIキー、商品PDF、Flutterアプリの接続先設定をまとめる。

対象の実行先:

- Windowsデスクトップ
- Chrome
- Androidエミュレーター
- Android実機

## 最初に理解すること

このセットアップで行うことは、大きく分けて次の2つ。

1. Python backendを起動する
2. Flutterアプリから、そのbackendへ接続できるURLを指定する

### Python backendを起動する理由

RAG機能では、FlutterアプリだけではAI応答を作らない。
商品PDFの読み込み、睡眠データと商品の組み合わせ、Gemini APIの呼び出しはPython backendが担当する。

そのため、FB画面でRAGのアドバイスや商品提案を使うには、先にPC上でPython backendを起動しておく必要がある。

```text
Flutterアプリ
  ↓ /rag_analyze へ問い合わせる
Python backend
  ├─ 商品PDFを読む
  ├─ Gemini APIを呼ぶ
  └─ 結果をFlutterへ返す
```

backendを起動するターミナルは、起動中ずっと使われる。
そのため、backend用とFlutter起動用でターミナルを分けると分かりやすい。

### 最初に開くターミナル数

通常の動作確認では、最初にターミナルを2個開く。

```text
ターミナル1: Python backend用
  - 仮想環境 `.venv` を有効化する
  - `GEMINI_API_KEY` を設定する
  - `python -m uvicorn ...` でbackendを起動し続ける

ターミナル2: Flutterアプリ用
  - `flutter run ...` でアプリを起動する
  - 実行先に応じて `RAG_BACKEND_BASE_URL` を指定する
```

必要に応じて、3個目のターミナルを開く。

```text
ターミナル3: 確認・補助作業用
  - `/health` でbackendの起動確認をする
  - `adb reverse` を実行する
  - `tools/sync_sleep_db.ps1 -Watch` でDBを随時コピーする
```

DB随時コピーは、backendのためではなく、Android内のSQLiteをPC側へ確認用コピーとして取り出すための補助作業。
RAG機能そのものを動かすだけなら必須ではない。

### backend URLを指定する理由

Flutterアプリは、Python backendがどこで動いているかをURLで知る必要がある。
同じPCで動かすか、Androidエミュレーターで動かすか、Android実機で動かすかによって、指定するURLが変わる。

| 実行先 | backend起動 | Flutter側のbackend URL | 各自で変えるもの |
|---|---|
| Windowsデスクトップ | `--host 127.0.0.1` | 省略可、または `http://127.0.0.1:8000` | 基本なし |
| Chrome | `--host 127.0.0.1` | 省略可、または `http://127.0.0.1:8000` | 基本なし |
| Androidエミュレーター | `--host 127.0.0.1` | `http://10.0.2.2:8000` | `flutter devices` で表示されるデバイスID |
| Android実機 | `--host 0.0.0.0` | `http://各自PCのLAN IP:8000` | PCのLAN IP、デバイスID、必要に応じてFirewall |

注意点:

- `127.0.0.1` は「今動いている端末自身」を指す。
- Androidエミュレーター上の `127.0.0.1` はPCではなくエミュレーター自身を指すため、PC上のbackendへ接続するには `10.0.2.2` を使う。
- Android実機はPCとは別端末なので、PCと同じWi-Fiに接続し、PCのLAN IPを指定する。

### 共有時に全員同じでよいもの

以下は基本的に全員同じでよい。

- 仮想環境名: `.venv`
- backendのポート番号: `8000`
- Windowsデスクトップ/Chromeのbackend URL: `http://127.0.0.1:8000`
- Androidエミュレーターのbackend URL: `http://10.0.2.2:8000`
- backend起動モジュール: `lib.features.fb.backend.main:app`

Androidエミュレーターで使う `10.0.2.2` は、Androidエミュレーターから見た「ホストPC」を表す特別なIP。
そのため、エミュレーターで確認する人は、通常このURLを変更しない。

### 各自で確認して置き換えるもの

以下はPCや端末によって変わるため、共有されたコマンドをそのまま貼らず、自分の環境に合わせて置き換える。

#### プロジェクトフォルダ

手順内の `D:\4_26_f\Solution\smfb_app` は、この資料を作成した環境での配置場所。
別の場所にcloneした場合は、自分の `smfb_app` の場所に置き換える。

```powershell
cd 自分のPC上のsmfb_appフォルダ
```

例:

```powershell
cd D:\work\smfb_app
```

#### FlutterのデバイスID

Androidエミュレーターや実機のIDは、人によって違う。
次のコマンドで確認する。

```powershell
flutter devices
```

表示例:

```text
emulator-5554  • sdk gphone64 x86 64 • android-x64    • Android 15
windows        • Windows             • windows-x64    • Microsoft Windows
chrome         • Chrome              • web-javascript • Google Chrome
```

この場合、Androidエミュレーターで起動するなら `emulator-5554` を使う。
`<device-id>` という文字をそのまま入力せず、表示されたIDに置き換える。

```powershell
flutter run -d emulator-5554 --dart-define=RAG_BACKEND_BASE_URL=http://10.0.2.2:8000
```

#### Android実機で使うPCのLAN IP

Android実機で確認する場合だけ、PCのLAN IPを確認する。
PCとAndroid実機は同じWi-Fiに接続しておく。

```powershell
ipconfig
```

`Wi-Fi` または使用中のネットワークアダプターに表示される `IPv4 アドレス` を見る。

```text
IPv4 アドレス . . . . . . . . . . . .: 192.168.1.23
```

この例では、Flutter側のbackend URLは次のようにする。

```powershell
flutter run -d <device-id> --dart-define=RAG_BACKEND_BASE_URL=http://192.168.1.23:8000
```

実機からPCへアクセスするため、backendは `127.0.0.1` ではなく `0.0.0.0` で起動する。

```powershell
python -m uvicorn lib.features.fb.backend.main:app --host 0.0.0.0 --port 8000
```

#### Gemini APIキー

APIキーは共有ドキュメントに直接書かない。
backendを起動するターミナルで、各自が環境変数に設定する。

```powershell
$env:GEMINI_API_KEY = "ここにGemini APIキー"
```

#### adbの場所

`adb reverse` やDBコピーで `adb` が必要になる場合がある。
まず次のコマンドで `adb` が見つかるか確認する。

```powershell
where.exe adb
```

見つからない場合は、Android SDKの `platform-tools` 配下にある `adb.exe` をフルパスで指定する。
Windowsユーザー名やAndroid SDKの場所は人によって違う。

```powershell
& "C:\Users\<Windowsユーザー名>\AppData\Local\Android\sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

## 全体構成

RAGシステムは、Flutterアプリ単体では完結しない。
アプリとは別に、ローカルPC上でPython FastAPI backendを起動する必要がある。

```text
Flutterアプリ
  ↓ HTTP POST /rag_analyze
Python FastAPI backend
  ├─ data/products/*.pdf を読み込む
  ├─ 睡眠データと商品候補からプロンプトを作る
  └─ Gemini API を呼び出す
```

## 事前準備

### 必要なもの

- Flutter SDK
- Android Studio / Android SDK
- Python 3
- Chrome
- Gemini APIキー

### Flutter依存の取得

```powershell
cd D:\4_26_f\Solution\smfb_app
flutter pub get
```

### ローカル設定ファイル

`lib/features/fb/application/config/analysis_config.dart.example` を同じフォルダにコピーし、`analysis_config.dart` を作る。

```powershell
Copy-Item `
  "lib/features/fb/application/config/analysis_config.dart.example" `
  "lib/features/fb/application/config/analysis_config.dart"
```

`analysis_config.dart` は `.gitignore` 対象のローカル設定ファイル。
APIキー実値はコミットしない。

アプリ側のRAG backend URLは、基本的に起動時の `--dart-define=RAG_BACKEND_BASE_URL=...` で指定する。
未指定の場合は `http://127.0.0.1:8000` が使われる。

## Gemini APIキー

推奨は、Python backendを起動するターミナルで環境変数に設定する方法。

```powershell
$env:GEMINI_API_KEY = "ここにGemini APIキー"
```

毎回設定したくない場合は、ユーザー環境変数として保存する。
保存後、新しいPowerShellを開き直す。

```powershell
[Environment]::SetEnvironmentVariable(
  "GEMINI_API_KEY",
  "ここにGemini APIキー",
  "User"
)
```

backendは `GEMINI_API_KEY` または `GOOGLE_API_KEY` を見る。

## 商品PDF

商品PDFは次のフォルダに置く。

```text
data/products/
  *.pdf
```

現在確認済みのPDF:

- `data/products/寝具商品カタログ.pdf`
- `data/products/食品商品カタログ.pdf`

PDF追加・差し替え後は、backendを再起動する。
PDF loaderは読み込み結果をキャッシュするため、起動中のbackendには新しいPDFが反映されない場合がある。

## Python backend

### 初回セットアップ

Python backendは、プロジェクト直下の仮想環境 `.venv` で実行する。
依存パッケージをPC全体のPython環境へ入れないため、共有時もこの手順を使う。

```powershell
cd D:\4_26_f\Solution\smfb_app

py -m venv .venv

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

.\.venv\Scripts\Activate.ps1

python -m pip install -r lib/features/fb/backend/requirements.txt
```

以降、backendを起動するPowerShellでは、先に仮想環境を有効化する。

```powershell
cd D:\4_26_f\Solution\smfb_app
.\.venv\Scripts\Activate.ps1
```

### 起動

PC内だけから使う場合:

```powershell

python -m uvicorn lib.features.fb.backend.main:app --host 127.0.0.1 --port 8000
```

Android実機など、同じWi-Fi上の別端末から使う場合:

```powershell

python -m uvicorn lib.features.fb.backend.main:app --host 0.0.0.0 --port 8000
```

### 起動確認

別ターミナルで実行する。
このターミナルでも仮想環境を有効化してから確認する。

```powershell
cd D:\4_26_f\Solution\smfb_app
.\.venv\Scripts\Activate.ps1
python -c "import requests; print(requests.get('http://127.0.0.1:8000/health').json())"
```

期待例:

```text
{'status': 'ok', 'prompt_version': '1.0'}
```

## Windowsデスクトップで確認する場合

Windowsデスクトップアプリとして実行する場合、PC上のFlutterアプリとbackendは同じPCで動く。
そのため、backend URLは `http://127.0.0.1:8000` でよい。

backend:

```powershell
python -m uvicorn lib.features.fb.backend.main:app --host 127.0.0.1 --port 8000
```

Flutter:

```powershell
flutter run -d windows
```

注意:

- Windowsデスクトップ実行にはVisual StudioのC++開発環境が必要。
- `flutter doctor -v` でWindows desktopの項目を確認する。

## Chromeで確認する場合

Chromeで実行する場合も、Chromeとbackendが同じPCで動くなら `http://127.0.0.1:8000` でよい。

backend:

```powershell
python -m uvicorn lib.features.fb.backend.main:app --host 127.0.0.1 --port 8000
```

Flutter:

```powershell
flutter run -d chrome
```

補足:

- backend側はCORSを許可しているため、Chromeから `/rag_analyze` を呼べる。
- Chromeで動かす場合、SQLiteは使えないため `SleepRepository` / SharedPreferences側のフォールバック入力になる。

## Androidエミュレーターで確認する場合

Androidエミュレーターから見た `127.0.0.1` は、PCではなくエミュレーター自身を指す。
そのため、PC上のbackendへ接続するには次のどちらかを使う。

### 推奨: `10.0.2.2` を使う

backend:

```powershell
python -m uvicorn lib.features.fb.backend.main:app --host 127.0.0.1 --port 8000
```

Flutter:

`<device-id>` は `flutter devices` で表示されたAndroidエミュレーターのIDに置き換える。
例: `emulator-5554`

```powershell
flutter devices
flutter run -d <device-id> --dart-define=RAG_BACKEND_BASE_URL=http://10.0.2.2:8000
```

### 代替: adb reverseを使う

`adb` がPATHに入っていない場合は、フルパスで実行する。

```powershell
& "C:\Users\user\AppData\Local\Android\sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
flutter run -d emulator-5554
```

`adb reverse` を使う場合、アプリ側はデフォルトの `http://127.0.0.1:8000` のままでよい。

## Android実機で確認する場合

Android実機では `10.0.2.2` は使えない。
PCと実機を同じWi-Fiに接続し、PCのLAN IPへアクセスする。

### 1. PCのIPアドレスを確認

```powershell
ipconfig
```

例:

```text
IPv4 アドレス . . . . . . . . . . . .: 192.168.1.23
```

### 2. backendを外部待受で起動

```powershell
python -m uvicorn lib.features.fb.backend.main:app --host 0.0.0.0 --port 8000
```

### 3. Flutterを実機向けURLで起動

端末IDは `flutter devices` で確認する。

```powershell
flutter devices
flutter run -d <device-id> --dart-define=RAG_BACKEND_BASE_URL=http://192.168.1.23:8000
```

### 4. Windows Defender Firewall

実機から接続できない場合は、Windows Defender FirewallでPythonの受信を許可する。
または、一時的に同一ネットワークからのTCP 8000番を許可する。

注意:

- debug実行では `android/app/src/debug/AndroidManifest.xml` に `INTERNET` permissionがある。
- release/profileでHTTP接続する場合は、main manifest側の `INTERNET` permissionやHTTP cleartext設定を別途確認する。
- 本番運用ではHTTPではなくHTTPS化する。

## 動作確認手順

Flutterアプリを起動したら、FB画面で以下を確認する。

1. 通常アドバイスが表示される。
2. `寝具` ボタンで寝具PDF由来の商品名、メーカー、価格が表示される。
3. `食べ物` ボタンで食品PDF由来の商品名、メーカー、価格が表示される。
4. チャットで質問するとRAG backendから応答が返る。

確認済みの例:

- `オルソピロー 整体師監修 頸椎サポート枕`
- `メディカルスリープ研究所`
- `¥18,000`
- `スリープマスター プレミアム低反発枕`
- `ナイトウェル株式会社`
- `¥12,800`

## よくある問題

### `adb` が認識されない

PATHにAndroid SDK platform-toolsが入っていない。
フルパスで実行する。

```powershell
& "C:\Users\if682\AppData\Local\Android\sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

### `/rag_analyze` が失敗する

確認項目:

- backendが起動しているか。
- `GEMINI_API_KEY` または `GOOGLE_API_KEY` が設定されているか。
- アプリの `RAG_BACKEND_BASE_URL` が実行先に合っているか。
- PDF追加後にbackendを再起動したか。

### PDFの商品が出ない

確認項目:

- PDFが `data/products/*.pdf` に置かれているか。
- backendを再起動したか。
- PDFが画像だけでなくテキスト抽出できる形式か。

簡易確認:

```powershell
python -c "from lib.features.fb.backend.services.product_pdf_loader import load_product_documents; docs=load_product_documents(); print(len(docs), [len(d.text) for d in docs])"
```

### PowerShellで日本語が文字化けする

HTTPレスポンス自体は正常でも、PowerShell表示上で文字化けする場合がある。
確認だけならASCIIエスケープで出力する。

```powershell
python -c "import json; print(json.dumps({'text':'確認'}, ensure_ascii=True))"
```

