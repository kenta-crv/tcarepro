"""入力値のバリデーション関数群.

Ruby実装のバリデーションをPythonで再現するユーティリティ。
各関数は True/False を返す（True: 検証OK）。
"""

import re


def _is_blank(value: str) -> bool:
    """空（None, 空文字, 空白のみ）判定を行う.

    Args:
        value: 判定対象の文字列。

    Returns:
        bool: 空相当であれば True。

    """
    return value is None or str(value).strip() == ""


def validate_company_format(company: str) -> bool:
    """会社名の形式を検証する.

    次の条件を満たすかを検証し、満たさない場合はエラーメッセージを返す。
    - 「株式会社/有限会社/社会福祉/合同会社/医療法人/行政書士/一般社団法人/合資会社/法律事務所」
      のいずれかを含むこと
    - 支店・営業所・カッコ・スペース（半角/全角）を含まないこと
    - 全角英数字・記号（！-～の範囲）を含まないこと

    Args:
        company: 対象の会社名。

    Returns:
        bool: 条件をすべて満たせば True。

    """
    text = company or ""
    if not re.search(
        r"株式会社|有限会社|社会福祉|合同会社|医療法人|行政書士|一般社団法人|合資会社|法律事務所",
        text,
    ):
        return False

    if re.search(r"店|営業所|\(|\)|（|）|\s|　", text):
        return False

    return not re.search(r"[Ａ-Ｚａ-ｚ０-９！-～]", text)


def validate_tel_format(tel: str) -> bool:
    """電話番号の形式を検証する.

    次の条件を検証し、満たさない場合はエラーメッセージを返す。
    - 半角数字とハイフンのみ、かつハイフンが含まれていること
    - 数字のみ、または () が含まれていたらエラー

    Args:
        tel: 対象の電話番号文字列。

    Returns:
        bool: 条件をすべて満たせば True。

    """
    target = tel or ""

    if not re.fullmatch(r"[0-9\-]+", target):
        return False
    if "-" not in target:
        return False
    if re.fullmatch(r"[0-9]+", target):
        return False
    return not ("(" in target or ")" in target)


def validate_address_format(address: str) -> bool:
    """住所の形式を検証する.

    - 「都/道/府/県」のいずれかを含むこと。

    Args:
        address: 住所文字列。

    Returns:
        bool: 「都/道/府/県」を含めば True。

    """
    return bool(re.search(r"都|道|府|県", address or ""))


def valid_business(required_businesses: str, customer_business: str) -> bool:
    """事業（業種）の必須条件を満たすかを判定する.

    Args:
        required_businesses: カンマ区切りの必須業種文字列。
        customer_business: 顧客側の業種文字列。

    Returns:
        bool: 条件を満たせば True。

    """
    if _is_blank(required_businesses):
        return True
    if _is_blank(customer_business):
        return False
    required_list = [x.strip() for x in (required_businesses or "").split(",") if x.strip()]
    return any(req in customer_business for req in required_list)


def valid_genre(required_genre: str, customer_genre: str) -> bool:
    """ジャンルの必須条件を満たすかを判定する.

    Args:
        required_genre: カンマ区切りの必須ジャンル文字列。
        customer_genre: 顧客側のジャンル文字列。

    Returns:
        bool: 条件を満たせば True。

    """
    if _is_blank(required_genre):
        return True
    if not _is_blank(customer_genre):
        return any(
            req.strip() and req.strip() in customer_genre for req in required_genre.split(",")
        )
    return False
