# モデル使用状況調査レポート

## 調査日時
2025-11-19

## 調査結果

### 1. 実際に使用されているコードパス

✅ **`app.py`は`agent.agent.extract_company_info`を使用**
- `app.py` → `agent.agent.extract_company_info` → `agent/nodes.py`の関数を使用

### 2. `agent/nodes.py`のモデル指定

すべての箇所で`gemini-2.0-flash-lite`を使用：

1. **`node_get_url_candidates`** (75行目)
   - モデル: `gemini-2.0-flash-lite`
   - Google検索ツール: ✅ 使用 (`tools=[GenAITool(google_search={})]`)

2. **`node_select_official_website`** (220行目)
   - モデル: `gemini-2.0-flash-lite`
   - Google検索ツール: ❌ 使用していない

3. **`node_fetch_html`** (299行目)
   - モデル: `gemini-2.0-flash-lite`
   - Google検索ツール: ❌ 使用していない

### 3. 未使用のコード

⚠️ **`extract_company_info/extract_company_info.py`**
- このファイルは`gemini-2.5-flash`を使用しているが、`app.py`からは使われていない
- `main.py`から使われている可能性があるが、実際の処理では使用されていない

### 4. ダッシュボードの状況

- `gemini-2.5-flash`: RPM 10/10、RPD 252/250（制限超過）
- `gemini-2.0-flash-lite`: RPM 6/30、RPD 67/200（余裕あり）

## 結論

### ✅ コード上では`gemini-2.0-flash-lite`を使用している

しかし、ダッシュボードでは`gemini-2.5-flash`が制限に達している。

### 考えられる原因

1. **Google検索ツール使用時の自動フォールバック**
   - `gemini-2.0-flash-lite`でGoogle検索ツールを使用する際、バックエンドで自動的に`gemini-2.5-flash`にフォールバックしている可能性
   - LangChainのドキュメントでは、Google検索ツールの例で`gemini-2.5-flash`が使われている

2. **他のプロセス/スクリプトでの使用**
   - `extract_company_info.py`や`main.py`が別のプロセスで実行されている可能性
   - 他のアプリケーションやテストスクリプトで`gemini-2.5-flash`が使われている可能性

3. **API側の制限**
   - `gemini-2.0-flash-lite`がGoogle検索ツールをサポートしていない場合、API側で自動的に`gemini-2.5-flash`に切り替えている可能性

## 推奨事項

1. **ログで実際に使用されているモデルを確認**
   - APIレスポンスのメタデータに使用されたモデル名が含まれている可能性がある
   - ログにモデル名を記録するように修正

2. **`extract_company_info.py`の使用状況を確認**
   - `main.py`が実行されているか確認
   - 不要であれば削除または無効化

3. **Google検索ツールの使用を一時的に無効化してテスト**
   - `gemini-2.5-flash`の使用量が減るか確認

4. **APIレスポンスのメタデータを確認**
   - 実際に使用されたモデル名を確認

