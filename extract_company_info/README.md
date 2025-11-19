# extract_company_info

会社情報抽出システム

## セットアップ

### 前提条件

- Python 3.9以上
- pip（Pythonパッケージマネージャー）

### 自動セットアップ（推奨）

セットアップスクリプトを実行します：

```bash
cd extract_company_info
./setup_venv.sh
```

スクリプトは以下を自動で実行します：
1. Python バージョンの確認
2. 仮想環境の作成（既存の場合は削除確認）
3. 依存パッケージのインストール
4. 動作確認

### 手動セットアップ

セットアップスクリプトが使えない場合は、以下の手順で手動セットアップできます：

```bash
cd extract_company_info

# 仮想環境の作成
python3 -m venv venv

# 仮想環境の有効化
source venv/bin/activate  # Linux/Mac
# または
venv\Scripts\activate  # Windows

# pipのアップグレード
pip install --upgrade pip setuptools wheel

# 依存パッケージのインストール
pip install -r requirements.txt

# 開発用依存パッケージのインストール（オプション）
pip install -r requirements-dev.txt
```

### 環境変数の設定

1. `.env.example`を`.env`にコピー
2. `GOOGLE_API_KEY`を設定

```bash
cp .env.example .env
# .envファイルを編集してGOOGLE_API_KEYを入力
```

### 動作確認

仮想環境を有効化した状態で、以下を実行して動作確認できます：

```bash
source venv/bin/activate
python3 -c "import pydantic; import langchain_google_genai; import crawl4ai; print('OK')"
```

## 使用方法

仮想環境を有効化した状態で、`app.py`を実行します：

```bash
source venv/bin/activate
python3 app.py
```

## 除外URLについて

`.env`の「EXCLUDE_DOMAIN_LIST」に改行区切りで入力。
ここで指定した文字列を含むWebサイトは抽出から除外される

## 注意事項

- 仮想環境（`venv/`）はgitに含まれていません
- 各環境で仮想環境を個別に作成してください
- 仮想環境が壊れた場合は、削除して再作成してください