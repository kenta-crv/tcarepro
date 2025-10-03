"""ネットワーク/URLユーティリティ.

HTTP取得とURL正規化を提供します。
"""

import requests


def convert_accessable_urls(urls: list[str], timeout: int = 15) -> list[str]:
    """与えられたURL群を到達確認し、到達可能な最終URLに正規化して返す.

    リダイレクトを考慮し、`requests` の最終URL (`Response.url`) を採用する。
    失敗したURLは結果から除外する。

    Args:
        urls (list[str]): 確認対象のURL候補群。
        timeout (int): タイムアウト秒。デフォルトは15秒。

    Returns:
        list[str]: 到達可能だったURLの配列。

    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    }
    new_urls = []
    for url in urls:
        try:
            r = requests.get(url, headers=headers, timeout=timeout)
            r.raise_for_status()  # 4xx/5xx を例外に
            new_urls.append(r.url)
        except requests.exceptions.RequestException:  # noqa: PERF203
            pass

    return new_urls
