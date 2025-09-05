import json
import sys
from contextlib import suppress

from pydantic import ValidationError

from logutil import get_logger
from schemas import CompanyInfo, ErrorDetail, ExtractRequest, ExtractResponse
from service import extract_company_profile

## ロガーは logutil.get_logger() を利用する


def _write_response(response: ExtractResponse, exit_code: int) -> None:
    """標準出力にJSONを出力して終了コードで終了する.

    Args:
        response (ExtractResponse): 出力するレスポンスモデル。
        exit_code (int): プロセス終了コード。

    """
    # 出力JSONを生成
    out_json = json.dumps(response.model_dump(), ensure_ascii=False)

    # 出力JSONをログに書き出す
    # 形式: {"event": "output", "json": <JSON文字列>, "exit_code": <int>}
    try:
        logger = get_logger()
        logger.info(
            "%s",
            json.dumps(
                {"event": "output", "json": out_json, "exit_code": exit_code},
                ensure_ascii=False,
            ),
        )
    except Exception as log_err:  # noqa: BLE001
        # ログ出力失敗は本処理に影響させない（標準エラーには通知）
        with suppress(Exception):
            sys.stderr.write(f"[log-error] {log_err}\n")

    # 標準出力に書き込み、終了コードで終了
    sys.stdout.write(out_json)
    sys.exit(exit_code)


def main() -> None:
    """標準入力JSONを検証し会社情報抽出を実行する."""
    # 1) 標準入力から JSON を読み取り
    raw = sys.stdin.buffer.read()
    try:
        # 入力JSONをログに書き出す
        # 形式: {"event": "input", "json": <入力文字列>}
        logger = get_logger()
        logger.info(
            "%s",
            json.dumps(
                {"event": "input", "json": raw.decode("utf-8", errors="replace")},
                ensure_ascii=False,
            ),
        )
    except Exception as log_err:  # noqa: BLE001
        # ログ出力失敗は本処理に影響させない（標準エラーには通知）
        with suppress(Exception):
            sys.stderr.write(f"[log-error] {log_err}\n")
    if not raw:
        # 入力が空の場合は INPUT_ERROR で返す
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="INPUT_ERROR", message="stdinにJSONが必要です"),
            ),
            2,
        )

    # 2) JSON の解析とスキーマ検証
    try:
        data = json.loads(raw)  # JSON デコード
        payload = ExtractRequest.model_validate(data)  # スキーマ検証
    except (ValidationError, TypeError, json.JSONDecodeError):
        # 解析/検証いずれの失敗も INPUT_ERROR として返す
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="INPUT_ERROR", message="JSONの解析に失敗しました"),
            ),
            2,
        )

    # 3) メイン処理実行
    try:
        # 新APIを直接呼び出し
        info: CompanyInfo = extract_company_profile(payload)
        # 4) 成功レスポンス
        _write_response(ExtractResponse(success=True, data=info), 0)
    except ValidationError as e:
        # CompanyInfo への整形・検証段階での失敗
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="PROCESSING_ERROR", message=str(e)),
            ),
            1,
        )


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # noqa: BLE001
        # 予期しない処理系エラー
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(
                    code="UNEXPECTED_ERROR",
                    message=str(e),
                ),
            ),
            1,
        )
