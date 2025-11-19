"""utils.crawl4ai_util の単体テスト.

`AsyncWebCrawler` をモックしてネットワークへ出ずに検証する。
"""

from pytest_mock import MockerFixture

from utils import crawl4ai_util


def test_crawl_markdown_concatenates_results(mocker: MockerFixture) -> None:
    """複数結果の `markdown` が連結されて返ることを確認する.

    非同期クローラはモックし、`arun` が `markdown` 属性を持つ
    オブジェクトの配列を返すように設定する。
    """

    class DummyResult:
        # 簡易的なダミー戻り値
        def __init__(self, text: str) -> None:
            self.markdown = text

    dummy_instance = mocker.MagicMock()
    # asyncio.wait_forでラップされるため、コルーチンを返す必要がある
    async def mock_arun(*args, **kwargs):
        return [DummyResult("A"), DummyResult("B")]
    dummy_instance.arun = mock_arun

    # 非同期のコンテキストマネージャとして振る舞うよう設定
    dummy_cm = mocker.MagicMock()
    dummy_cm.__aenter__.return_value = dummy_instance
    dummy_cm.__aexit__.return_value = False
    mocker.patch.object(crawl4ai_util, "AsyncWebCrawler", return_value=dummy_cm)

    out = crawl4ai_util.crawl_markdown("https://example.com")
    assert out == "AB"


def test_crawl_markdown_returns_empty_on_exception(mocker: MockerFixture) -> None:
    """例外発生時に空文字を返すことを確認する."""
    dummy_instance = mocker.MagicMock()
    async def mock_arun(*args, **kwargs):
        raise RuntimeError("boom")
    dummy_instance.arun = mock_arun

    dummy_cm = mocker.MagicMock()
    dummy_cm.__aenter__.return_value = dummy_instance
    dummy_cm.__aexit__.return_value = False
    mocker.patch.object(crawl4ai_util, "AsyncWebCrawler", return_value=dummy_cm)

    out = crawl4ai_util.crawl_markdown("https://example.com")
    assert out == ""


def test_crawl_markdown_uses_deep_strategy_when_depth_positive(
    mocker: MockerFixture,
) -> None:
    """depth>=1 のときに DeepCrawl の設定が渡されることを確認する.

    `arun` の呼び出し引数 `config` に `deep_crawl_strategy` が
    セットされていることを検証する。
    """

    call_args_list = []
    async def mock_arun(*args, **kwargs):
        call_args_list.append((args, kwargs))
        return []
    dummy_instance = mocker.MagicMock()
    dummy_instance.arun = mock_arun

    dummy_cm = mocker.MagicMock()
    dummy_cm.__aenter__.return_value = dummy_instance
    dummy_cm.__aexit__.return_value = False
    mocker.patch.object(crawl4ai_util, "AsyncWebCrawler", return_value=dummy_cm)

    _ = crawl4ai_util.crawl_markdown("https://example.com", depth=2)

    # 引数検証
    assert len(call_args_list) == 1
    _, kwargs = call_args_list[0]
    assert "config" in kwargs
    config = kwargs["config"]
    assert getattr(config, "deep_crawl_strategy", None) is not None


def test_crawl_markdown_uses_normal_strategy_when_depth_zero(
    mocker: MockerFixture,
) -> None:
    """depth==0 のときに DeepCrawl が無効であることを確認する."""

    call_args_list = []
    async def mock_arun(*args, **kwargs):
        call_args_list.append((args, kwargs))
        return []
    dummy_instance = mocker.MagicMock()
    dummy_instance.arun = mock_arun

    dummy_cm = mocker.MagicMock()
    dummy_cm.__aenter__.return_value = dummy_instance
    dummy_cm.__aexit__.return_value = False
    mocker.patch.object(crawl4ai_util, "AsyncWebCrawler", return_value=dummy_cm)

    _ = crawl4ai_util.crawl_markdown("https://example.com", depth=0)

    # 引数検証
    assert len(call_args_list) == 1
    _, kwargs = call_args_list[0]
    assert "config" in kwargs
    config = kwargs["config"]
    assert getattr(config, "deep_crawl_strategy", None) is None
