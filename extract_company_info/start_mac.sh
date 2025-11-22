#!/bin/bash
# extract_company_info Mac向け起動スクリプト
# 既存のプロセスを停止し、venvを作成して起動します

set -e  # エラーが発生したら終了

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
APP_FILE="${SCRIPT_DIR}/app.py"

echo "=========================================="
echo "extract_company_info Mac向け起動スクリプト"
echo "=========================================="
echo ""

# 1. 既存のプロセスを停止
echo "既存のプロセスを確認中..."
EXISTING_PIDS=$(ps aux | grep -E "python.*app\.py|extract_company_info.*app\.py" | grep -v grep | awk '{print $2}' || true)

if [ -n "$EXISTING_PIDS" ]; then
    echo "既存のプロセスが見つかりました:"
    ps aux | grep -E "python.*app\.py|extract_company_info.*app\.py" | grep -v grep
    echo ""
    echo "既存のプロセスを停止中..."
    echo "$EXISTING_PIDS" | xargs kill -9 2>/dev/null || true
    sleep 2
    echo "✅ 既存のプロセスを停止しました"
    echo ""
else
    echo "✅ 既存のプロセスはありません"
    echo ""
fi

# 2. Python バージョンチェック
echo "Python バージョンを確認中..."
if ! command -v python3 &> /dev/null; then
    echo "❌ エラー: python3 が見つかりません"
    echo "   Python 3.9以上をインストールしてください"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 9 ]); then
    echo "❌ エラー: Python 3.9以上が必要です（現在: Python ${PYTHON_VERSION}）"
    exit 1
fi

echo "✅ Python ${PYTHON_VERSION} を確認"
echo ""

# 3. 仮想環境の作成（存在しない場合）
if [ ! -d "$VENV_DIR" ]; then
    echo "仮想環境を作成中: ${VENV_DIR}"
    python3 -m venv "$VENV_DIR"
    echo "✅ 仮想環境作成完了"
    echo ""
    
    # 仮想環境の有効化
    echo "仮想環境を有効化中..."
    source "${VENV_DIR}/bin/activate"
    echo "✅ 仮想環境を有効化しました"
    echo ""
    
    # pipのアップグレード
    echo "pipをアップグレード中..."
    pip install --upgrade pip setuptools wheel > /dev/null 2>&1
    echo "✅ pipアップグレード完了"
    echo ""
    
    # 依存パッケージのインストール
    if [ -f "$REQUIREMENTS_FILE" ]; then
        echo "依存パッケージをインストール中: ${REQUIREMENTS_FILE}"
        pip install -r "$REQUIREMENTS_FILE" > /dev/null 2>&1
        echo "✅ 依存パッケージインストール完了"
        echo ""
    else
        echo "⚠️  警告: ${REQUIREMENTS_FILE} が見つかりません"
    fi
else
    echo "✅ 既存の仮想環境を使用: ${VENV_DIR}"
    echo ""
    # 仮想環境の有効化
    echo "仮想環境を有効化中..."
    source "${VENV_DIR}/bin/activate"
    echo "✅ 仮想環境を有効化しました"
    echo ""
fi

# 4. アプリケーションの起動（ログをコマンドラインに出力）
if [ ! -f "$APP_FILE" ]; then
    echo "❌ エラー: ${APP_FILE} が見つかりません"
    exit 1
fi

echo "=========================================="
echo "アプリケーションを起動します"
echo "=========================================="
echo "ログはコマンドラインに出力されます"
echo "停止するには Ctrl+C を押してください"
echo "=========================================="
echo ""

# アプリケーションを起動（ログを標準出力に出力）
cd "$SCRIPT_DIR"
python3 "$APP_FILE" 2>&1

