# パフォーマンス分析：API呼び出し時間が長い原因

## 問題の概要

レート制限に達していないのに、API呼び出しに非常に時間がかかる問題について分析します。

## 実際のAPI呼び出し時間

ログを確認した結果、**API呼び出し自体は3-4秒程度**で、それほど遅くありません：

- Google Searchツール使用時: **2.83秒〜4.75秒**（平均3-4秒）
- 公式サイト選定: **1.20秒〜12.10秒**（平均2-6秒）

## 時間がかかっている原因

### 1. 待機時間が長すぎる ⚠️

現在の実装では、Google Searchツール使用後に**合計7秒**の待機時間があります：

```python
# Google Searchツール使用後
time.sleep(2.0)  # 追加待機時間
_wait_between_api_calls()  # 通常の5秒
# 合計: 7秒
```

**問題点**:
- API呼び出し自体が3-4秒なのに、その後7秒待機するのは過剰
- レート制限に達していない場合、この待機時間は不要

### 2. URL到達可能性チェックに時間がかかる ⚠️⚠️

`convert_accessable_urls`関数は、各URLに対して**30秒のタイムアウト**でHTTPリクエストを送信します：

```python
def convert_accessable_urls(urls: list[str], timeout: int = 30) -> list[str]:
    # 各URLに対して30秒のタイムアウト
    r = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True)
```

**問題点**:
- URLが5個ある場合、最悪で**150秒（2.5分）**かかる可能性
- タイムアウトが長すぎる（30秒）
- 並列処理していないため、順次実行される

### 3. クロール処理に時間がかかる ⚠️

`crawl_markdown`関数は、各URLに対して**20-30秒のタイムアウト**でクロールします：

```python
# node_select_official_website内
markdown = crawl_markdown(url, timeout=20)  # 20秒タイムアウト

# node_fetch_html内
web_context = crawl_markdown(url, depth=0, timeout=30)  # 30秒タイムアウト
```

**問題点**:
- 複数のURLを順次クロールするため、時間がかかる
- タイムアウトが長すぎる

## 推奨される対策

### 1. 待機時間の最適化 ✅ 推奨

レート制限に達していない場合、待機時間を短縮：

```python
# 現在: 7秒（2秒 + 5秒）
# 推奨: 3秒（Google Searchツール使用時のみ追加1秒 + 通常2秒）
if google_search_tool:
    time.sleep(1.0)  # Google Searchツール使用時のみ追加1秒
_wait_between_api_calls()  # 通常の2秒に短縮
```

### 2. URL到達可能性チェックの最適化 ✅ 推奨

- タイムアウトを短縮: 30秒 → **10秒**
- 並列処理を検討（`concurrent.futures`を使用）
- 失敗したURLは早期にスキップ

### 3. クロール処理の最適化 ✅ 推奨

- タイムアウトを短縮: 20-30秒 → **10秒**
- 並列処理を検討
- 失敗したURLは早期にスキップ

## 次のステップ

1. 待機時間を短縮（7秒 → 3秒）
2. URL到達可能性チェックのタイムアウトを短縮（30秒 → 10秒）
3. 並列処理を実装して処理時間を短縮

