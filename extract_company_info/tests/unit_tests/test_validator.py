"""validator ユーティリティのユニットテスト."""

import pytest

from utils.validator import (
    valid_business,
    valid_genre,
    validate_address_format,
    validate_company_format,
    validate_tel_format,
)


def test_validate_company_format_basic_ok() -> None:
    """会社名: 正常系（株式会社〜などを含み、禁止パターンなし)."""
    assert validate_company_format("株式会社テスト") is True


@pytest.mark.parametrize(
    "name",
    [
        "テスト店",
        "テスト営業所",
        "株式会社テスト (東京)",
        "株式会社テスト（東京）",
        "株 式 会 社 テ ス ト",
        "株式会社テスト　東京",  # 全角スペース
    ],
)
def test_validate_company_format_banned_tokens(name: str) -> None:
    """会社名: 禁止文字/語を含む場合はエラー."""
    assert validate_company_format(name) is False


def test_validate_company_format_fullwidth_alnum_symbol() -> None:
    """会社名: 全角英数字・記号を含むとエラー."""
    assert validate_company_format("株式会社ＡＢＣ１２３！") is False


def test_validate_company_format_requires_corporate_word() -> None:
    """会社名: 法人格キーワードが無いとエラー."""
    assert validate_company_format("テストホールディングス") is False


def test_validate_tel_format_ok() -> None:
    """電話番号: 数字とハイフンのみ、かつハイフンありはOK."""
    assert validate_tel_format("03-1234-5678") is True


@pytest.mark.parametrize("tel", ["0312345678", "(03)1234-5678", "03)1234(5678)"])
def test_validate_tel_format_invalid_patterns(tel: str) -> None:
    """電話番号: 数字のみや () を含むとエラー."""
    assert validate_tel_format(tel) is False


def test_validate_address_format_ok() -> None:
    """住所: 都道府県のいずれかを含むとOK."""
    assert validate_address_format("東京都千代田区") is True


def test_validate_address_format_ng() -> None:
    """住所: 都道府県を含まないとエラー."""
    assert validate_address_format("東京千代田区") is False


def test_valid_business_true_when_contains_any_required() -> None:
    """業種: 必須のいずれかを含めばTrue."""
    assert valid_business("IT,製造", "当社はITと教育の事業") is True


def test_valid_business_false_when_blank_customer() -> None:
    """業種: 顧客業種が空ならFalse."""
    assert valid_business("IT,製造", "") is False


def test_valid_genre_required_blank_always_true() -> None:
    """ジャンル: 必須が空ならTrue."""
    assert valid_genre("", "何でも可") is True


def test_valid_genre_true_when_contains_any_required() -> None:
    """ジャンル: 顧客ジャンルが必須のいずれかを含めばTrue."""
    assert valid_genre("IT,製造", "IT/教育/物流") is True


def test_valid_genre_false_when_required_present_but_customer_blank() -> None:
    """ジャンル: 必須があって顧客が空ならFalse."""
    assert valid_genre("IT,製造", "") is False
