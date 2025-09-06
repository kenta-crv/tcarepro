from utils.crawl4ai_util import crawl_markdown


def test_crawl_markdown_success() -> None:
    # フィクスチャから入力と期待値を取得
    markdown = crawl_markdown("https://www.example.com")
    assert "Example Domain" in markdown
