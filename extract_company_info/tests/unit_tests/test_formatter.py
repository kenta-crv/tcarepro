"""formtter ユーティリティのユニットテスト."""

from utils.formtter import normalize_company_name, normalize_tel_number


def test_normalize_company_name_removes_spaces_and_fullwidth_to_halfwidth() -> None:
    """会社名: 空白除去と全角→半角の正規化を確認する."""
    src = "株 式 会 社ＡＢＣ１２３！　テ ス ト"
    out = normalize_company_name(src)
    assert out == "株式会社ABC123!テスト"


def test_normalize_company_name_none_safe() -> None:
    """会社名: None でも安全に空文字を返す."""
    assert normalize_company_name(None) == ""


def test_normalize_tel_number_fullwidth_digits_to_halfwidth() -> None:
    """電話: 全角数字と括弧・ハイフンを半角に正規化する."""
    src = "（０３）１２３４−５６７８"
    out = normalize_tel_number(src)
    assert out == "(03)1234-5678"


def test_normalize_tel_number_none_safe() -> None:
    """電話: None でも安全に空文字を返す."""
    assert normalize_tel_number(None) == ""
