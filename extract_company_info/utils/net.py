"""ネットワーク/URLユーティリティ.

HTTP取得とURL正規化を提供します。
"""

import requests
import urllib3
from concurrent.futures import ThreadPoolExecutor, as_completed
from utils.logger import get_logger

# SSL警告を抑制
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logger = get_logger()


def _check_single_url(url: str, timeout: int, headers: dict) -> str | None:
    """単一URLの到達可能性をチェックする（並列処理用）.
    
    Args:
        url: チェック対象のURL
        timeout: タイムアウト秒
        headers: HTTPヘッダー
    
    Returns:
        到達可能なURL（最終URL）またはNone
    """
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
                return None
        
        r = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True, verify=False)
        r.raise_for_status()  # 4xx/5xx を例外に
        logger.debug(f"  ✅ URL到達確認成功: {url} -> {r.url}")
        return r.url
    except requests.exceptions.HTTPError as e:
        # 404の場合、ルートURLを試す
        if e.response.status_code == 404:
            logger.debug(f"  ⚠️ 404エラー: {url} - ルートURLを試行")
            try:
                from urllib.parse import urlparse
                parsed = urlparse(url)
                root_url = f"{parsed.scheme}://{parsed.netloc}/"
                
                r = requests.get(root_url, headers=headers, timeout=timeout, allow_redirects=True, verify=False)
                r.raise_for_status()
                logger.debug(f"  ✅ ルートURL到達確認成功: {root_url} -> {r.url}")
                return r.url
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
    return None


def convert_accessable_urls(urls: list[str], timeout: int = 10) -> list[str]:
    """与えられたURL群を到達確認し、到達可能な最終URLに正規化して返す.

    リダイレクトを考慮し、`requests` の最終URL (`Response.url`) を採用する。
    失敗したURLは結果から除外する。404の場合はルートURLも試す。
    並列処理により、複数URLのチェックを高速化する。

    Args:
        urls (list[str]): 確認対象のURL候補群。
        timeout (int): タイムアウト秒。デフォルトは10秒（30秒から短縮してパフォーマンス改善）。

    Returns:
        list[str]: 到達可能だったURLの配列。

    """
    if not urls:
        return []
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    }
    new_urls = []
    checked_urls = set()  # 重複チェック用
    
    # 並列処理でURL到達可能性をチェック（最大5並列）
    max_workers = min(5, len(urls))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # 各URLのチェックを並列実行
        future_to_url = {
            executor.submit(_check_single_url, url, timeout, headers): url
            for url in urls
        }
        
        for future in as_completed(future_to_url):
            result = future.result()
            if result and result not in checked_urls:
                new_urls.append(result)
                checked_urls.add(result)
    
    if new_urls:
        return new_urls

    # すべて到達失敗した場合は、フォールバックとして元のURLを返す
    logger.debug("  ⚠️ すべてのURLで到達確認に失敗したため、元の候補をフォールバックとして返します")
    return urls
