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
    logger.info("=" * 80)
    logger.info("[APP START] extract_company_info アプリケーション起動")
    logger.info("=" * 80)
    
    # 1) 標準入力から JSON を読み取り
    logger.info("[STEP 1/5] 標準入力からJSON読み取り中...")
    raw = sys.stdin.buffer.read()
    logger.info(f"  ✅ 読み取り完了: {len(raw)}バイト")
    
    # ログ出力用の customer_id（入力JSONに含まれる想定）
    try:
        customer_id = json.loads(raw)["customer_id"]
        logger.info(f"  customer_id: {customer_id}")
    except:
        customer_id = None
        logger.warning("  ⚠️ customer_idが見つかりません")
    
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
        logger.error("[ERROR] 標準入力が空です")
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="INPUT_ERROR", message="stdinにJSONが必要です"),
            ),
            2,
            customer_id=customer_id,
        )

    # 2) JSON の解析とスキーマ検証
    logger.info("[STEP 2/5] JSON解析とスキーマ検証中...")
    try:
        data = json.loads(raw)  # JSON デコード
        logger.info("  ✅ JSON解析成功")
        payload = ExtractRequest.model_validate(data)  # スキーマ検証
        logger.info("  ✅ スキーマ検証成功")
        logger.info(f"     会社名: {payload.company}")
        logger.info(f"     所在地: {payload.location}")
    except (ValidationError, TypeError, json.JSONDecodeError) as e:
        # 解析/検証いずれの失敗も INPUT_ERROR として返す
        logger.error(f"  ❌ JSON解析/検証失敗: {type(e).__name__}")
        logger.error(f"     {str(e)[:200]}")
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="INPUT_ERROR", message="JSONの解析に失敗しました"),
            ),
            2,
            customer_id=customer_id,
        )

    # 3) メイン処理実行
    logger.info("[STEP 3/5] メイン処理実行（Agent呼び出し）...")
    try:
        # Agent側に処理委譲（入力: ExtractRequest → 出力: CompanyInfo）
        info: CompanyInfo = extract_company_info(payload)
        # 4) 成功レスポンス
        logger.info("[STEP 4/5] 成功レスポンス作成中...")
        _write_response(ExtractResponse(success=True, data=info), 0, customer_id=customer_id)
    except ValidationError as e:
        # CompanyInfo への整形・検証段階での失敗
        logger.error("[ERROR] CompanyInfo検証エラー")
        logger.error(f"  {type(e).__name__}: {str(e)[:200]}")
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="PROCESSING_ERROR", message=str(e)),
            ),
            1,
            customer_id=customer_id,
        )
    except ValueError as e:
        # URL候補が見つからない、クロール失敗などの処理エラー
        logger.error(f"[ERROR] 処理エラー: {type(e).__name__}")
        logger.error(f"  {str(e)[:500]}")
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code="PROCESSING_ERROR", message=str(e)[:500]),
            ),
            1,
            customer_id=customer_id,
        )
    except Exception as e:
        # API制限エラーやその他のエラーをキャッチ
        error_message = str(e)
        error_code = "API_ERROR"
        
        # 429エラー（クォータ超過）を検出
        if "429" in error_message or "quota" in error_message.lower() or "ResourceExhausted" in error_message:
            error_code = "QUOTA_EXCEEDED"
            error_message = "Gemini API quota exceeded. Please wait or use a different API key."
            logger.error("[ERROR] Gemini APIクォータ超過")
            logger.error(f"  再試行は行いません（max_retries=2で制限）")
        else:
            logger.error(f"[ERROR] 予期しないエラー: {type(e).__name__}")
            logger.error(f"  {str(e)[:500]}")
        
        _write_response(
            ExtractResponse(
                success=False,
                error=ErrorDetail(code=error_code, message=error_message[:500]),
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
