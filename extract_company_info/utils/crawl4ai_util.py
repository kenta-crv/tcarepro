"""crawl4ai を用いた簡易クローリングユーティリティ.

外部モジュールから呼び出しやすいように、URLとクロール深さを引数に取り
マークダウン文字列を返す同期関数 `crawl_markdown` を提供する。
内部実装は非同期クローラ（AsyncWebCrawler）を使用する。
"""

import asyncio
import contextlib
import io

from crawl4ai import AsyncWebCrawler, CrawlerRunConfig
from crawl4ai.content_scraping_strategy import LXMLWebScrapingStrategy
from crawl4ai.deep_crawling import BFSDeepCrawlStrategy


async def _acrawl_markdown(url: str, depth: int = 0, timeout: int = 30) -> str:
    """指定URLをクロールし、Markdownを連結して返す非同期関数.

    深さが1以上の場合はディープクロール（BFS）を行い、0の場合は通常クロールを行う。

    Args:
        url (str): 対象URL。
        depth (int, optional): クロールの深さ。1以上でディープクロール。既定は0。
        timeout (int, optional): タイムアウト秒数。既定は30秒。

    Returns:
        str: 取得できたMarkdownの連結文字列（失敗時は空文字）。

    """
    import logging
    logger = logging.getLogger(__name__)
    
    # 設定を生成（深さに応じてディープクロールを有効化）
    deep_strategy = None
    if depth and depth >= 1:
        deep_strategy = BFSDeepCrawlStrategy(max_depth=depth, max_pages=10)
        logger.debug(f"  crawl4ai: ディープクロール有効 (depth={depth}, max_pages=10)")

    config = CrawlerRunConfig(
        deep_crawl_strategy=deep_strategy,
        scraping_strategy=LXMLWebScrapingStrategy(),
    )

    async with AsyncWebCrawler() as crawler:
        try:
            # タイムアウトを設定
            logger.debug(f"  crawl4ai: クロール開始: {url} (timeout={timeout}秒, depth={depth})")
            result = await asyncio.wait_for(
                crawler.arun(url=url, config=config),
                timeout=timeout
            )
            logger.debug(f"  crawl4ai: クロール成功: {url}")
        except asyncio.TimeoutError:
            logger.warning(f"  crawl4ai: タイムアウト: {url} (timeout={timeout}秒, depth={depth})")
            return ""
        except Exception as e:  # noqa: BLE001
            # 失敗時は空文字
            logger.warning(f"  crawl4ai: エラー: {url} - {type(e).__name__}: {str(e)[:200]}")
            import traceback
            logger.debug(f"  crawl4ai: トレースバック: {traceback.format_exc()}")
            return ""

        # 返り値が配列（ディープクロール）か単一かを吸収
        try:
            # リスト/イテラブル想定で連結を試みる
            markdown = "".join((getattr(r, "markdown", "") or "") for r in result)  # type: ignore[arg-type]
            logger.debug(f"  crawl4ai: Markdown取得成功 (ディープクロール): {len(markdown)}文字")
            return markdown
        except TypeError:
            # 単一オブジェクト
            markdown = getattr(result, "markdown", "") or ""
            logger.debug(f"  crawl4ai: Markdown取得成功 (通常クロール): {len(markdown)}文字")
            return markdown


def crawl_markdown(url: str, depth: int = 0, timeout: int = 30) -> str:
    """指定URLをクロールし、Markdown文字列を返す同期関数.

    非同期クローラ実装を内部で実行する。既にイベントループが動作中なら
    新規ループで実行する。

    Args:
        url (str): 対象URL。
        depth (int, optional): クロールの深さ。1以上でディープクロール。既定は0。
        timeout (int, optional): タイムアウト秒数。既定は30秒。

    Returns:
        str: 取得できたMarkdownの連結文字列（失敗時は空文字）。

    """
    with contextlib.redirect_stdout(io.StringIO()):
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # 既存ループが走っている場合は新規に実行
                return asyncio.run(_acrawl_markdown(url, depth, timeout))  # type: ignore[no-any-return]
            return loop.run_until_complete(_acrawl_markdown(url, depth, timeout))
        except RuntimeError:
            # ループ未存在などのケース
            return asyncio.run(_acrawl_markdown(url, depth, timeout))
