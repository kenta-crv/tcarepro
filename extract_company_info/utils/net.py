"""ネットワーク/URLユーティリティ.

HTTP取得とURL正規化を提供します。
"""

import requests
from utils.logger import get_logger

logger = get_logger()


def convert_accessable_urls(urls: list[str], timeout: int = 30) -> list[str]:
    """与えられたURL群を到達確認し、到達可能な最終URLに正規化して返す.

    リダイレクトを考慮し、`requests` の最終URL (`Response.url`) を採用する。
    失敗したURLは結果から除外する。404の場合はルートURLも試す。

    Args:
        urls (list[str]): 確認対象のURL候補群。
        timeout (int): タイムアウト秒。デフォルトは30秒（15秒から延長）。

    Returns:
        list[str]: 到達可能だったURLの配列。

    """
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    }
    new_urls = []
    checked_urls = set()  # 重複チェック用
    
    for url in urls:
        try:
            # DNS解決を事前に確認
            from urllib.parse import urlparse
            parsed = urlparse(url)
            hostname = parsed.hostname
            if hostname:
                try:
                    import socket
                    socket.gethostbyname(hostname)
                except socket.gaierror:
                    logger.debug(f"  ❌ DNS解決失敗: {hostname}")
                    continue
            
            r = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True)
            r.raise_for_status()  # 4xx/5xx を例外に
            if r.url not in checked_urls:
                new_urls.append(r.url)
                checked_urls.add(r.url)
                logger.debug(f"  ✅ URL到達確認成功: {url} -> {r.url}")
        except requests.exceptions.HTTPError as e:
            # 404の場合、ルートURLを試す
            if e.response.status_code == 404:
                logger.debug(f"  ⚠️ 404エラー: {url} - ルートURLを試行")
                try:
                    from urllib.parse import urlparse
                    parsed = urlparse(url)
                    root_url = f"{parsed.scheme}://{parsed.netloc}/"
                    
                    if root_url not in checked_urls:
                        r = requests.get(root_url, headers=headers, timeout=timeout, allow_redirects=True)
                        r.raise_for_status()
                        if r.url not in checked_urls:
                            new_urls.append(r.url)
                            checked_urls.add(r.url)
                            logger.debug(f"  ✅ ルートURL到達確認成功: {root_url} -> {r.url}")
                except Exception as e2:  # noqa: BLE001
                    logger.debug(f"  ❌ ルートURL試行失敗: {type(e2).__name__}: {str(e2)[:100]}")
            else:
                logger.debug(f"  ❌ HTTPエラー ({e.response.status_code}): {url}")
        except requests.exceptions.Timeout:
            logger.debug(f"  ❌ タイムアウト ({timeout}秒): {url}")
        except requests.exceptions.ConnectionError as e:
            logger.debug(f"  ❌ 接続エラー: {url} - {str(e)[:100]}")
        except requests.exceptions.RequestException as e:  # noqa: PERF203
            logger.debug(f"  ❌ リクエストエラー: {url} - {type(e).__name__}: {str(e)[:100]}")

    return new_urls
