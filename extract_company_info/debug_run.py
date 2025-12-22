import os
import sys

# 【重要】インポートする前に、現在のディレクトリを検索パスに追加する
current_dir = os.getcwd()
sys.path.append(current_dir)

# パス設定後にインポートを実行
try:
    from models.schemas import ExtractRequest
    from agent.agent import extract_company_info
except ModuleNotFoundError as e:
    print(f"エラー: モジュールが見つかりません。\n現在のディレクトリ: {current_dir}")
    print(f"見つからないモジュール: {e}")
    print("ディレクトリ構造を確認してください (ls コマンドなどで models フォルダがあるか確認)")
    sys.exit(1)

# 動作確認用のダミーデータ
TEST_DATA = ExtractRequest(
    customer_id="test_user_001",
    company="株式会社トヨタ自動車",
    location="愛知県豊田市",
    required_businesses=["自動車製造"],
    required_genre=["メーカー"]
)

def run_debug():
    print(f"--- デバッグ開始: API Key Status: {'OK' if os.environ.get('GOOGLE_API_KEY') else 'MISSING'} ---")
    
    try:
        result = extract_company_info(TEST_DATA)
        print("\n=== 成功: 抽出結果 ===")
        print(f"会社名: {result.company}")
        print(f"住所: {result.address}")
        print(f"TEL: {result.tel}")
        print("======================")
    except Exception as e:
        print(f"\n=== 失敗: エラー発生 ===")
        print(e)

if __name__ == "__main__":
    run_debug()