"""app.main() の振る舞いテスト（モック不使用）。.

サブプロセスで `app.py` を実行し、標準入力/標準出力/終了コードを検証する。
"""

# ruff: noqa: S101,S603

import json
import sys
from pathlib import Path
from subprocess import CompletedProcess, run

import pytest

EXIT_INPUT_ERROR = 2


def _run_app_with_stdin(data: bytes) -> CompletedProcess:
    """`app.py` をサブプロセスで実行するヘルパー。.

    Args:
        data (bytes): 標準入力として渡すバイト列。

    Returns:
        subprocess.CompletedProcess: 実行結果（標準出力・終了コードなど）。

    """
    # テスト対象スクリプトのパスを解決
    script = Path(__file__).resolve().parent.parent / "app.py"
    return run(
        [sys.executable, str(script)],
        input=data,
        capture_output=True,
        check=False,
    )


def test_main_empty_input_returns_input_error() -> None:
    """標準入力が空の場合、INPUT_ERROR と終了コード2を返す。."""
    # 入力なし（空バイト列）
    proc = _run_app_with_stdin(b"")

    assert proc.returncode == EXIT_INPUT_ERROR

    # 出力JSONの検証
    payload = json.loads(proc.stdout.decode("utf-8"))
    assert payload["success"] is False
    assert payload["error"]["code"] == "INPUT_ERROR"
    assert "stdinにJSONが必要です" in payload["error"]["message"]


def test_main_invalid_json_returns_input_error() -> None:
    """壊れたJSONの場合、INPUT_ERROR と終了コード2を返す。."""
    proc = _run_app_with_stdin(b"{not-json}")

    assert proc.returncode == EXIT_INPUT_ERROR

    payload = json.loads(proc.stdout.decode("utf-8"))
    assert payload["success"] is False
    assert payload["error"]["code"] == "INPUT_ERROR"
    assert "JSONの解析に失敗しました" in payload["error"]["message"]


def test_main_invalid_schema_returns_input_error() -> None:
    """スキーマ不一致（必須項目不足）の場合、INPUT_ERROR と終了コード2を返す。."""
    # company のみを渡し、他の必須フィールドを欠落させる
    data = json.dumps({"company": "テスト株式会社"}, ensure_ascii=False).encode("utf-8")
    proc = _run_app_with_stdin(data)

    assert proc.returncode == EXIT_INPUT_ERROR

    payload = json.loads(proc.stdout.decode("utf-8"))
    assert payload["success"] is False
    assert payload["error"]["code"] == "INPUT_ERROR"
    assert "JSONの解析に失敗しました" in payload["error"]["message"]


@pytest.mark.skip
def test_main_success_like_input_no_exception() -> None:
    """正常系入力（有効なJSON）で例外が起きないことを確認する.

    出力内容の具体的なassertは行わず、処理が最後まで進み
    JSONとして出力されること（=例外でプロセスが異常終了しないこと）だけを確認する。
    なお、外部API/ネットワークはモックしない前提のため、
    実行結果の成否や終了コードはここでは検証しない。
    """
    payload = {
        "company": "有限会社テクノ大西",
        "location": "愛知県高浜市",
        "industry": "工場,食品",
        "genre": "",
    }
    proc = _run_app_with_stdin(json.dumps(payload, ensure_ascii=False).encode("utf-8"))

    # 出力はJSONであること（例外が出ないことのみ確認）
    json.loads(proc.stdout.decode("utf-8"))
