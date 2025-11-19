# Gemini API クォータ確認方法

## 1. Google Cloud Consoleで確認
1. https://console.cloud.google.com/ にアクセス
2. 「APIとサービス」→「クォータ」を選択
3. 「Vertex AI API」または「Generative Language API」を検索
4. 以下のクォータを確認：
   - **Requests per minute (RPM)**: 1分あたりのリクエスト数
   - **Tokens per minute (TPM)**: 1分あたりのトークン数
   - **Requests per day (RPD)**: 1日あたりのリクエスト数

## 2. Gemini API レート制限（参考）
- **Tier 1（無料）**: 
  - RPM: 15
  - TPM: 1,000,000
- **Tier 2（有料）**: 
  - RPM: 20,000
  - TPM: 10,000,000

## 3. 現在の使用状況
- 今日のAPI呼び出し数: 推定52.5回（21顧客 × 2.5回/顧客）
- 1顧客あたり: 2-3回のAPI呼び出し
  - URL候補取得: 1回
  - 公式サイト選定: 1回（URL候補が2個以上の場合）
  - 会社情報抽出: 1回
- 顧客間の間隔: 5秒（Worker側）
- API呼び出し間の間隔: 2秒（Python側、実装済み）

## 4. 実装済みの対策
- ✅ 各API呼び出しの間に2秒の間隔を追加
- ✅ 顧客間で5秒のスリープ
- ✅ 429エラー時のリトライ（4秒待機、最大2回試行）
- ✅ QUOTA_EXCEEDEDエラーの検出と停止

## 5. クォータ超過時の対処
1. Google Cloud Consoleでクォータを確認
2. 必要に応じてクォータの引き上げを申請
3. `API_CALL_INTERVAL_SECONDS`の値を調整（現在: 2秒）

