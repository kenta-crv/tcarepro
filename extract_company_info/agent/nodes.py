import random
import re

from google.ai.generativelanguage_v1beta.types import Tool as GenAITool
from langchain_core.prompts.loading import load_prompt
from langchain_google_genai import ChatGoogleGenerativeAI

from agent.state import ExtractState
from models.schemas import CompanyInfo, URLScoreList
from models.settings import BASE_DIR, settings
from utils.crawl4ai_util import crawl_markdown
from utils.logger import get_logger
from utils.net import convert_accessable_urls

logger = get_logger()


def node_get_url_candidates(state: ExtractState) -> ExtractState:
    """会社名・勤務地からURL候補を検索して状態を更新する.

    Args:
        state: LangGraphの状態ディクショナリ（`company`, `location` を想定）。

    Returns:
        dict: `urls` キーに候補URLの配列を追加した新しい状態。

    """
    logger.error("---URL抽出開始----")
    # プロンプトをYAMLからロード
    prompt = load_prompt(str(BASE_DIR / "agent/prompts/extract_url.yaml"), encoding="utf-8")
    # LLM（検索ツール有効）を呼び出し
    llm = ChatGoogleGenerativeAI(
        model="gemini-2.5-flash-lite",
        temperature=0,
        google_api_key=settings.GOOGLE_API_KEY,
    )
    resp = llm.invoke(
        prompt.format(company=state.company, location=state.location),
        tools=[GenAITool(google_search={})],
    )

    # 応答からURLを抽出
    urls: list[str] = []
    try:
        # grounding由来URL
        reference_urls = [
            chunk["web"]["uri"]
            for chunk in resp.response_metadata["grounding_metadata"]["grounding_chunks"]
        ]
    except Exception:  # noqa: BLE001
        reference_urls = []

    # 本文からURLを1つ抜き出す
    match = re.search(r"https?://[^\s]+", resp.content)
    if match:
        urls.append(match.group())
    urls.extend(reference_urls)

    # 除外ドメイン設定に基づいて候補URLをフィルタ
    # サブドメインも含めて末尾一致で除外する
    def _is_excluded(url: str) -> bool:
        # EXCLUDE_DOMAINS は改行区切りの文字列 or リストを想定
        raw = settings.EXCLUDE_DOMAINS
        domains = [s.strip() for s in raw.splitlines() if s.strip()]
        return any(domain in url for domain in domains)

    urls = [u for u in urls if not _is_excluded(u)]

    # 到達可能URLに正規化
    state.urls = convert_accessable_urls(urls)
    if not len(state.urls):
        logger.error("URLが抽出できませんでした")
        raise Exception("URLが抽出できませんでした")
    logger.error("---URL抽出終了----")
    return state


def node_select_official_website(state: ExtractState) -> ExtractState:
    """候補URLから公式サイトを一つ選定して状態を更新する.

    Args:
        state: `urls` を含む状態。

    Returns:
        dict: `selected_url` を追加した状態。

    """
    urls = state.urls
    web_context = ""
    for url in urls:
        markdown = crawl_markdown(url)
        web_context += f"""# {url}\n{markdown}\n"""
    prompt = load_prompt(str(BASE_DIR / "agent/prompts/select_official.yaml"), encoding="utf-8")
    r = random.randint(0, 4)  # noqa: S311
    models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.5-pro"]
    model = models[r % 3]
    llm = ChatGoogleGenerativeAI(
        model=model,
        temperature=0,
        google_api_key=settings.GOOGLE_API_KEY,
    ).with_structured_output(
        URLScoreList,
    )
    resp: URLScoreList = llm.invoke(
        prompt.format(company=state.company, location=state.location, web_context=web_context),
    )
    sorted_urls = sorted(resp.urls, key=lambda x: x.score, reverse=True)

    def _is_excluded(url: str) -> bool:
        # EXCLUDE_DOMAINS は改行区切りの文字列 or リストを想定
        raw = settings.EXCLUDE_DOMAINS
        domains = [s.strip() for s in raw.splitlines() if s.strip()]
        return any(domain in url for domain in domains)

    state.urls = [url.url for url in sorted_urls if not _is_excluded(url.url)]

    return state


def node_fetch_html(state: ExtractState) -> ExtractState:
    """選定URLのHTMLを取得し状態に格納する.

    Args:
        state: `selected_url` を含む状態。

    Returns:
        dict: `html` を追加した状態（失敗時は空文字）。

    """
    logger.error("---会社情報抽出開始----")
    url = state.urls.pop(0)
    web_context = crawl_markdown(url, depth=1)

    prompt = load_prompt(str(BASE_DIR / "agent/prompts/extract_contact.yaml"), encoding="utf-8")
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.5-flash",
            temperature=0,
            google_api_key=settings.GOOGLE_API_KEY,
        ).with_structured_output(
            CompanyInfo,
        )

        resp: CompanyInfo = llm.invoke(
            prompt.format(
                required_businesses=state.required_businesses,
                required_genre=state.required_genre,
                web_context=web_context,
            ),
        )
    except Exception as e:
        try:
            llm = ChatGoogleGenerativeAI(
                model="gemini-2.5-pro",
                temperature=0,
                google_api_key=settings.GOOGLE_API_KEY,
            ).with_structured_output(
                CompanyInfo,
            )

            resp: CompanyInfo = llm.invoke(
                prompt.format(
                    required_businesses=state.required_businesses,
                    required_genre=state.required_genre,
                    web_context=web_context,
                ),
            )
        except Exception as e:
            try:
                llm = ChatGoogleGenerativeAI(
                    model="gemini-2.5-flash-lite",
                    temperature=0,
                    google_api_key=settings.GOOGLE_API_KEY,
                ).with_structured_output(
                    CompanyInfo,
                )

                resp: CompanyInfo = llm.invoke(
                    prompt.format(
                        required_businesses=state.required_businesses,
                        required_genre=state.required_genre,
                        web_context=web_context,
                    ),
                )
            except Exception as e:
                logger.error("会社情報が抽出できませんでした")
                raise Exception("会社情報が抽出できませんでした")

    state.company_info = resp
    logger.error("---会社情報抽出完了----")
    return state
