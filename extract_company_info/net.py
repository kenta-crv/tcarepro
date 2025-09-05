"""ネットワーク/URLユーティリティ.

HTTP取得とURL正規化を提供します。
"""

import re
from typing import Optional
from urllib.parse import urlparse

import requests


def normalize_url(text: str) -> Optional[str]:
    """文字列から妥当なURLを生成する.

    既に ``http(s)://`` が先頭の場合はそのまま返し、
    それ以外は ``https://`` を付与して正規化します。パース不能な場合は ``None``。

    Args:
        text (str): URL候補の文字列。

    Returns:
        Optional[str]: 正規化済みURL。妥当でない場合は ``None``。

    """
    s = text.strip().strip(" '\"")  # 余計な空白や引用符を除去
    if not s:
        return None
    url = s if re.match(r"^https?://", s, re.IGNORECASE) else f"https://{s}"

    parsed = urlparse(url)
    return url if parsed.scheme and parsed.netloc else None


def fetch_html(url: str, timeout: int = 15) -> str:
    """指定URLのHTMLを取得する.

    Args:
        url (str): 取得対象のURL。
        timeout (int): タイムアウト秒。デフォルトは15秒。

    Returns:
        str: レスポンスのHTML文字列。

    Raises:
        requests.RequestException: 通信エラー、タイムアウト、HTTPエラーなど。

    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    }
    r = requests.get(url, headers=headers, timeout=timeout)
    r.raise_for_status()  # 4xx/5xx を例外に
    # 文字コード推定（charset-normalizerによる自動判別）
    r.encoding = r.apparent_encoding or r.encoding
    return r.text
