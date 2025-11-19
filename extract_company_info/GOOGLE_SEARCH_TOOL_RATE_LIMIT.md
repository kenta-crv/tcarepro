# Google Searchツール（Grounding API）のレート制限調査

## 概要

Gemini APIのGoogle Searchツール（Grounding API）を使用する際のレート制限について調査した結果をまとめます。

## 使用箇所

### 1. `node_get_url_candidates`（URL候補取得）
- **モデル**: `gemini-2.0-flash`
- **Google Searchツール**: ✅ 使用 (`tools=[GenAITool(google_search={})]`)
- **目的**: 会社名と所在地からURL候補を検索

### 2. `node_select_official_website`（公式サイト選定）
- **モデル**: `gemini-2.0-flash`
- **Google Searchツール**: ❌ 使用していない
- **目的**: 複数のURL候補から公式サイトを選定

### 3. `node_fetch_html`（会社情報抽出）
- **モデル**: `gemini-2.0-flash`
- **Google Searchツール**: ❌ 使用していない
- **目的**: 選定されたURLから会社情報を抽出

## 実際のエラー発生状況

### エラー発生ノードの分析

ログを確認した結果、429エラーは以下のノードで発生しています：

1. **Google検索ツール使用時**: 複数回発生
   - 例: 16:29:09, 16:32:24, 16:42:38
   - エラー発生率: 中程度

2. **公式サイト選定時**: 発生
   - 例: 17:09:34（Google検索ツールを使用していない）
   - エラー発生率: 低い

3. **会社情報抽出時**: 発生していない

### 結論

- **Google Searchツールを使用していないノードでも429エラーが発生**
- 429エラーの原因は、Google Searchツール固有のレート制限ではなく、**Gemini API全体のレート制限**の可能性が高い
- ただし、Google Searchツール使用時は追加の処理（検索API呼び出し）が発生するため、より慎重なレート制限対策が必要

## Google Searchツール（Grounding API）のレート制限

### 公式ドキュメントからの情報

[Gemini API公式ドキュメント](https://ai.google.dev/gemini-api/docs/google-search?hl=ja)によると：

1. **Google Searchツールの仕組み**
   - `google_search`ツールを有効にすると、モデルが情報の検索、処理、引用のワークフロー全体を自動的に処理
   - モデルがプロンプトを分析し、Google検索で回答を改善できるかどうかを判断
   - 必要に応じて、モデルは1つ以上の検索クエリを自動的に生成して実行
   - 検索結果を処理し、情報を合成して回答を作成

2. **レート制限について**
   - 公式ドキュメントには、Google Searchツール固有のレート制限についての明確な記載はない
   - **通常のGemini APIと同じレート制限が適用される可能性が高い**
   - RPM: 15回/分（無料プラン）
   - TPM: 1,000,000トークン/分（無料プラン）
   - RPD: 200回/日（無料プラン）

3. **重要なポイント**
   - Google Searchツールを使用すると、内部的にGoogle検索APIを呼び出す
   - 1回のAPI呼び出しで複数の検索クエリが実行される可能性がある
   - 検索結果の処理に時間がかかるため、API呼び出し時間が長くなる傾向がある

### 実際の動作

- Google Searchツールを使用すると、`grounding_metadata`がレスポンスに含まれる
- `grounding_chunks`には検索結果のURLが含まれる
- リダイレクトURL（`https://vertexaisearch.cloud.google.com/grounding-api-redirect/...`）が返される場合がある

## 実装済みの対策

### 1. Google Searchツール使用時の追加待機時間 ✅ 実装済み

Google Searchツールを使用する場合、通常のAPI呼び出しよりも長い待機時間を設定：

```python
# node_get_url_candidates内
# Google Searchツール使用時は追加の待機時間（2秒）
time.sleep(2.0)
_wait_between_api_calls()  # 通常の5秒
# 合計: 7秒の待機時間
```

### 2. エラーハンドリングの改善 ✅ 実装済み

- ResourceExhaustedエラーをクォータ超過と一時的なレート制限に区別
- エクスポネンシャルバックオフを実装

### 3. ログの詳細化 ✅ 実装済み

- Google Searchツール使用時のAPI呼び出しを詳細にログ出力
- 使用モデルと実際のモデルをログに記録

## 次のステップ

1. Google Cloud ConsoleでGrounding APIのクォータを確認
2. 実際の使用状況を監視して、Google Searchツール固有の制限があるか確認
3. 必要に応じて、追加の待機時間を調整

