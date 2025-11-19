import json

import pytest
from pytest_mock import MockerFixture

from app import main
from models.schemas import CompanyInfo


def test_main_fail_empty_input_returns_input_error(
    mocker: MockerFixture,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """標準入力が空の場合、INPUT_ERROR と終了コード2を返す。."""
    mocker.patch("app.sys.stdin.buffer.read", return_value=b"")
    with pytest.raises(SystemExit):
        main()
    captured = capsys.readouterr().out
    payload = json.loads(captured)

    assert payload["success"] is False
    assert payload["error"]["code"] == "INPUT_ERROR"
    assert "stdinにJSONが必要です" in payload["error"]["message"]


def test_main_fail_invalid_json_returns_input_error(
    mocker: MockerFixture,
    capsys: pytest.CaptureFixture[str],
) -> None:
    mocker.patch("app.sys.stdin.buffer.read", return_value=b"{not-json}")
    with pytest.raises(SystemExit):
        main()
    captured = capsys.readouterr().out
    payload = json.loads(captured)

    assert payload["success"] is False
    assert payload["error"]["code"] == "INPUT_ERROR"
    assert "JSONの解析に失敗しました" in payload["error"]["message"]


def test_main_fail_invalid_schema_returns_input_error(
    mocker: MockerFixture,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """スキーマ不一致（必須項目不足）の場合、INPUT_ERROR と終了コード2を返す。."""
    # company のみを渡し、他の必須フィールドを欠落させる
    data = json.dumps({"company": "テスト株式会社"}, ensure_ascii=False).encode("utf-8")

    mocker.patch("app.sys.stdin.buffer.read", return_value=data)
    with pytest.raises(SystemExit):
        main()
    captured = capsys.readouterr().out
    payload = json.loads(captured)

    assert payload["success"] is False
    assert payload["error"]["code"] == "INPUT_ERROR"
    assert "JSONの解析に失敗しました" in payload["error"]["message"]


def test_main_success_return_company_info(
    mocker: MockerFixture,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """正常系: agent.extract_company_info をモックし成功レスポンスを検証する."""
    # 入力JSON
    input_json = {
        "customer_id": "test_123",
        "company": "株式会社サンプル",
        "location": "愛知県高浜市",
        "required_businesses": ["工場", "食品"],
        "required_genre": ["食品製造"],
    }
    data = json.dumps(input_json, ensure_ascii=False).encode("utf-8")
    mocker.patch("app.sys.stdin.buffer.read", return_value=data)

    # 出力となる CompanyInfo をモック
    dummy_info = CompanyInfo.model_validate(
        {
            "company": "株式会社サンプル",
            "tel": "000-0000-0000",
            "address": "愛知県高浜市",
            "first_name": "山田太郎",
            "url": "https://example.com",
            "contact_url": "https://example.com/contact",
            "business": "食品",
            "genre": "食品製造",
        },
    )
    mocker.patch("app.extract_company_info", return_value=dummy_info)

    with pytest.raises(SystemExit) as e:
        main()
    assert e.value.code == 0

    captured = capsys.readouterr().out
    payload = json.loads(captured)
    assert payload["success"] is True
    parsed = CompanyInfo.model_validate(payload["data"])  # 型検証と値の確認
    assert parsed.company == "株式会社サンプル"
    assert parsed.tel == "000-0000-0000"
    assert parsed.address == "愛知県高浜市"
    assert parsed.first_name == "山田太郎"
    assert parsed.url == "https://example.com"
    assert parsed.contact_url == "https://example.com/contact"
    assert parsed.business == "食品"
    assert parsed.genre == "食品製造"
