# Gemini AI 実装 戦闘記録

## 背景

Flutter アプリ（睡眠記録アプリ）に Gemini AI を組み込み、睡眠データを分析してアドバイスを返す機能を実装した。

---

## 遭遇したエラーと原因・対処の全記録

| # | エラー | 原因 | 対処 |
|---|--------|------|------|
| 1 | HTTP 404 `gemini-1.5-flash` not found for v1beta | `gemini-1.5-flash` はこのAPIキーでは廃止済み | モデルを `gemini-2.0-flash` に変更 |
| 2 | HTTP 429 You exceeded your current quota | APIキーが**有料プロジェクト（Cloud Prepay）**に紐づいており残高¥0 | 新しいAPIキーを発行 |
| 3 | HTTP 429 新キーでも同じ | 新キーも同じ有料プロジェクトに紐づいていた | さらに別の新プロジェクト（課金なし）でキー発行 |
| 4 | HTTP 404 `gemini-1.5-flash-latest` not found for v1 | v1 エンドポイントはこのモデル非対応 | v1beta に戻す |
| 5 | HTTP 400 Unknown name "system_instruction" | v1 エンドポイントは `system_instruction` フィールド非対応 | v1beta + system_instruction の組み合わせに統一 |
| 6 | HTTP 429 新プロジェクト・新キーでも発生 | `gemini-2.0-flash-lite` 等の新しいモデルも無料枠では制限あり | ListModels API で使用可能モデル一覧を取得して調査 |
| 7 | HTTP 503 This model is currently experiencing high demand | `gemini-2.5-flash` のサーバー過負荷（一時的） | 3秒×2回の自動リトライを実装 |
| 8 | Markdownがそのまま表示 `**太字**` → `**太字**` | AI が `**text**` 形式で返すが Flutter は Markdown を自動レンダリングしない | `_stripMarkdown()` で除去 |
| 9 | `$1` が文中に混入 `まずは、$1ことから` | Dart の `replaceAll(regex, r'$1')` はグループ参照にならず文字列 `$1` が入る | `replaceAllMapped()` に修正 |
| 10 | 回答が途中で途切れる | `maxOutputTokens: 500` が少なすぎた（日本語は1文字≒複数token） | `1500` に増量 |

---

## 最終的に動いた構成

```
モデル    : gemini-2.5-flash
APIバージョン : v1beta
フィールド  : system_instruction + contents
キー     : 課金なしの新プロジェクトで発行したもの
```

---

## 教訓

- **APIキーはプロジェクト単位で管理される。** 有料プロジェクトに紐づくと無料枠が使えない
- **モデル名は時期によって変わる。** ListModels API で現在使えるモデルを確認するのが確実
- **v1 と v1beta は別物。** `system_instruction` は v1beta のみ対応
- **503は一時的。** リトライで解決する
- **日本語トークンは英語より消費が多い。** `maxOutputTokens` は余裕を持って設定する
- **Dart の正規表現置換は `replaceAllMapped()` を使う。** `r'$1'` はグループ参照にならない

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `lib/features/fb/infrastructure/api/api_client.dart` | Gemini API クライアント本体 |
| `lib/features/fb/application/config/analysis_config.dart` | APIキー設定（.gitignore済み） |
| `lib/features/fb/application/config/analysis_config.dart.example` | APIキーのテンプレート（git管理対象） |
| `lib/features/fb/presentation/pages/fb_dashboard_page.dart` | AI分析結果の表示画面 |
| `lib/features/fb/presentation/dialogs/fb_chat_dialog.dart` | AIチャットダイアログ |

---

*記録日: 2026年5月*  
*ブランチ: `features/ToT-pattern-fb-AI`*
