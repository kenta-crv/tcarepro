"""文字列の整形ユーティリティ.

会社名や電話番号の表記ゆれを正規化する関数を提供する。
"""

import re
import unicodedata


def normalize_company_name(name: str) -> str:
    """会社名の全角英数字・記号を半角へ、かつ空白を除去する.

    仕様:
    - 全角の英数字・記号は半角へ正規化（NFKC）。
    - 半角/全角スペースなどの空白はすべて削除。

    Args:
        name: 入力の会社名文字列。

    Returns:
        str: 正規化済みの会社名。

    """
    if name is None:
        return ""
    normalized = unicodedata.normalize("NFKC", str(name))
    return re.sub(r"\s+", "", normalized)


def normalize_tel_number(tel: str) -> str:
    """電話番号内の数値などを半角へ正規化する.

    NFKC 正規化により、全角数字や括弧・ハイフン等も半角へ揃える。

    Args:
        tel: 入力の電話番号文字列。

    Returns:
        str: 正規化済みの電話番号。

    """
    if tel is None:
        return ""
    s = unicodedata.normalize("NFKC", str(tel))
    # ハイフン風の記号を ASCII ハイフンに寄せる
    return re.sub(r"[\u2212\u2010-\u2015\uFF0D]", "-", s)
