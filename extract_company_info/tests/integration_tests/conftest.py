import pytest

from models.schemas import CompanyInfo, ExtractRequest


@pytest.fixture
def sample_dataset() -> tuple[ExtractRequest, CompanyInfo]:
    return (
        ExtractRequest(
            customer_id="test_integration_001",
            company="北海道古川電気工業株式会社",
            location="北海道 札幌市 栄町駅 車15分",
            required_businesses=["工場"],
            required_genre=["部品生産"],
        ),
        CompanyInfo(
            company="北海道古川電気工業株式会社",
            business="工場",
            address="北海道札幌市東区北丘珠4条4丁目2番60号",
            url="https://www.h-furukawa.com",
            contact_url="https://www.h-furukawa.com/contact",
            first_name="茂泉勝弘",
            genre="部品生産",
            tel="011-791-5701",
        ),
    )
