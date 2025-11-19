#!/bin/bash
# extract_company_info 仮想環境セットアップスクリプト
# Python 3.9以上が必要です

set -e  # エラーが発生したら終了

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
REQUIREMENTS_DEV_FILE="${SCRIPT_DIR}/requirements-dev.txt"

echo "=========================================="
echo "extract_company_info 仮想環境セットアップ"
echo "=========================================="
echo ""

# Python バージョンチェック
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

# 既存の仮想環境を削除（オプション）
if [ -d "$VENV_DIR" ]; then
    echo "既存の仮想環境が見つかりました: ${VENV_DIR}"
    read -p "削除して再作成しますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "既存の仮想環境を削除中..."
        rm -rf "$VENV_DIR"
        echo "✅ 削除完了"
    else
        echo "既存の仮想環境を使用します"
    fi
    echo ""
fi

# 仮想環境の作成
if [ ! -d "$VENV_DIR" ]; then
    echo "仮想環境を作成中: ${VENV_DIR}"
    python3 -m venv "$VENV_DIR"
    echo "✅ 仮想環境作成完了"
    echo ""
fi

# 仮想環境の有効化
echo "仮想環境を有効化中..."
source "${VENV_DIR}/bin/activate"
echo "✅ 仮想環境を有効化しました"
echo ""

# pipのアップグレード
echo "pipをアップグレード中..."
pip install --upgrade pip setuptools wheel
echo "✅ pipアップグレード完了"
echo ""

# 依存パッケージのインストール
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "依存パッケージをインストール中: ${REQUIREMENTS_FILE}"
    pip install -r "$REQUIREMENTS_FILE"
    echo "✅ 依存パッケージインストール完了"
    echo ""
else
    echo "⚠️  警告: ${REQUIREMENTS_FILE} が見つかりません"
fi

# 開発用依存パッケージのインストール（オプション）
if [ -f "$REQUIREMENTS_DEV_FILE" ]; then
    read -p "開発用依存パッケージもインストールしますか？ (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "開発用依存パッケージをインストール中: ${REQUIREMENTS_DEV_FILE}"
        pip install -r "$REQUIREMENTS_DEV_FILE"
        echo "✅ 開発用依存パッケージインストール完了"
        echo ""
    fi
fi

# 動作確認
echo "動作確認中..."
python3 -c "import pydantic; import langchain_google_genai; import crawl4ai; print('✅ 主要パッケージのインポートに成功しました')" || {
    echo "❌ エラー: パッケージのインポートに失敗しました"
    exit 1
}
echo ""

echo "=========================================="
echo "✅ セットアップ完了！"
echo "=========================================="
echo ""
echo "仮想環境を有効化するには:"
echo "  source ${VENV_DIR}/bin/activate"
echo ""
echo "仮想環境を無効化するには:"
echo "  deactivate"
echo ""

