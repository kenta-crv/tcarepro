import json
import sys
from contextlib import suppress
from typing import Optional

from pydantic import ValidationError

from agent.agent import extract_company_info
from models.schemas import CompanyInfo, ErrorDetail, ExtractRequest, ExtractResponse
from utils.logger import get_logger

logger = get_logger()

def _write_response(
    response: ExtractResponse,
    exit_code: int,
    customer_id: str,
) -> None:
    """標準出力にJSONを出力して終了コードで終了する.

    Args:
        response (ExtractResponse): 出力するレスポンスモデル。
        exit_code (int): プロセス終了コード。
        customer_id (str, optional): ログに含める `customer_id`。標準入力に含まれる場合のみ設定。

    """
    # 出力JSONを生成
    out_json = json.dumps(response.model_dump(), ensure_ascii=False)

    # 出力JSONをログに書き出す
    # 形式: {"event": "output", "json": <JSON文字列>, "exit_code": <int>}
    payload = {
        "customer_id": customer_id,
        "event": "output",
        "json": out_json,
        "exit_code": exit_code,
    }
    logger.info("%s", json.dumps(payload, ensure_ascii=False))

    # 標準出力に書き込み、終了コードで終了
    sys.stdout.write(out_json)
    sys.exit(exit_code)


def main() -> None:
    """標準入力JSONを検証し会社情報抽出を実行する."""
    # 1) 標準入力から JSON を読み取り
    raw = sys.stdin.buffer.read()
    # ログ出力用の customer_id（入力JSONに含まれる想定）
    customer_id = json.loads(raw)["customer_id"]
    # 入力JSONをログに書き出す
    # 形式: {"event": "input", "json": <入力文字列>}
    input_payload = {
        "customer_id": customer_id,
        "event": "input",
        "json": raw.decode("utf-8", errors="replace"),
    }
    logger.info("%s", json.dumps(input_payload, ensure_ascii=False))
    if not raw:
        # 入力が空の場合は INPUT_ERROR で返す
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="INPUT_ERROR", message="stdinにJSONが必要です"),
            ),
            2,
            customer_id=customer_id,
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
            customer_id=customer_id,
        )

    # 3) メイン処理実行
    try:
        # Agent側に処理委譲（入力: ExtractRequest → 出力: CompanyInfo）
        info: CompanyInfo = extract_company_info(payload)
        # 4) 成功レスポンス
        _write_response(ExtractResponse(success=True, data=info), 0, customer_id=customer_id)
    except ValidationError as e:
        # CompanyInfo への整形・検証段階での失敗
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="PROCESSING_ERROR", message=str(e)),
            ),
            1,
            customer_id=customer_id,
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
            customer_id=None,
        )
