import pytest
from pytest_mock import MockerFixture

from agent import agent
from models.schemas import ExtractRequest


class DummyGraph:
    def __init__(self, payload: dict) -> None:
        self.payload = payload

    def invoke(self, _state: dict) -> dict:
        return self.payload


def test_extract_company_info_fills_address_from_location(mocker: MockerFixture) -> None:
    """住所に『都/道/府/県』が含まれない場合、location を用いて補完する."""

    dummy_result = {
        "company_info": {
            "company": "株式会社テスト",
            "tel": "000-0000-0000",
            "address": "川口市戸塚安行駅3-1-1",  # 県名なし -> location で補完される
            "first_name": "山田太郎",
            "url": "https://example.com",
            "contact_url": "https://example.com/contact",
            "business": "介護",
            "genre": "介護サービス",
        },
    }

    mocker.patch(
        "agent.agent.compile_graph",
        return_value=DummyGraph(dummy_result),
    )

    req = ExtractRequest(
        customer_id="test_001",
        company="株式会社テスト",
        location="埼玉県川口市戸塚安行駅",
        required_businesses=[],
        required_genre=[],
    )

    info = agent.extract_company_info(req)

    assert info.address.startswith("埼玉県"), "location で住所が補完されていること"

