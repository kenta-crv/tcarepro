"""agent.extract_company_info の統合テスト.

conftest.py のフィクスチャを用いて入力・期待値を共有する。
外部サービスのモックは行わず、シンプルに入出力を検証する。
"""

from agent.agent import extract_company_info
from models.schemas import CompanyInfo, ExtractRequest


def test_extract_company_info_returns_company_info(
    sample_dataset: tuple[ExtractRequest, CompanyInfo],
) -> None:
    """フィクスチャから入力を受け取り、期待どおりの CompanyInfo が生成されることを検証する.

    注意: 外部サービス呼び出しをモックしていないため、ネットワーク環境に依存します。
    URL候補が見つからない場合（DNS解決失敗など）はテストをスキップします。

    Args:
        sample_dataset: `conftest.py` が提供する `(ExtractRequest, CompanyInfo)` のタプル。

    """
    import pytest
    
    # フィクスチャから入力と期待値を取得
    req, expected = sample_dataset

    # SUT の実行
    try:
        actual = extract_company_info(req)
    except ValueError as e:
        # URL候補が見つからない場合（DNS解決失敗など）はスキップ
        if "URL候補が見つかりませんでした" in str(e):
            pytest.skip(f"URL候補が見つかりませんでした（ネットワーク環境の問題の可能性）: {e}")
        raise

    # 主要フィールドの一致を確認
    assert actual.company == expected.company
    assert actual.business in req.required_businesses
    assert actual.address == expected.address
    assert actual.url.rstrip("/") == expected.url.rstrip("/")
    assert actual.contact_url.rstrip("/") == expected.contact_url.rstrip("/")
    assert actual.first_name == expected.first_name
    assert actual.tel == expected.tel
    assert any(genre in actual.genre for genre in req.required_genre)
