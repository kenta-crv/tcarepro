import re
import time

from google.ai.generativelanguage_v1beta.types import Tool as GenAITool
from google.api_core.exceptions import ResourceExhausted
from langchain_core.prompts.loading import load_prompt
from langchain_google_genai import ChatGoogleGenerativeAI

from agent.state import ExtractState
from models.schemas import CompanyInfo, LLMCompanyInfo, URLScoreList
from models.settings import BASE_DIR, settings
from utils.crawl4ai_util import crawl_markdown
from utils.net import convert_accessable_urls
from utils.logger import get_logger

RETRY_DELAY_SECONDS = 4.0
RETRY_ATTEMPTS = 1  # 1回リトライ = 最大2回試行

logger = get_logger()


def _invoke_with_retry(llm, prompt_str: str, *, retries: int = RETRY_ATTEMPTS, **invoke_kwargs):
    """Gemini API呼び出しを最大retries回再試行（4秒待機）で実行."""
    attempts = retries + 1
    for attempt in range(attempts):
        try:
            return llm.invoke(prompt_str, **invoke_kwargs)
        except ResourceExhausted as exc:
            if attempt == retries:
                raise
            logger.warning(
                "  ⚠️ Gemini APIクォータ超過 (attempt %s/%s). %s秒待機して再試行します…",
                attempt + 1,
                attempts,
                RETRY_DELAY_SECONDS,
            )
            time.sleep(RETRY_DELAY_SECONDS)
        except Exception:
            raise


def node_get_url_candidates(state: ExtractState) -> ExtractState:
    """会社名・勤務地からURL候補を検索して状態を更新する.

    Args:
        state: LangGraphの状態ディクショナリ（`company`, `location` を想定）。

    Returns:
        dict: `urls` キーに候補URLの配列を追加した新しい状態。

    """
    node_start = time.time()
    logger.info("-" * 60)
    logger.info("[NODE 1/3] node_get_url_candidates - URL候補の取得")
    logger.info(f"  入力: {state.company} @ {state.location}")
    
    # プロンプトをYAMLからロード
    prompt = load_prompt(str(BASE_DIR / "agent/prompts/extract_url.yaml"), encoding="utf-8")
    logger.debug("  ✅ プロンプトロード完了")

    # LLM（検索ツール有効）を呼び出し
    # max_retries=2に制限して無限ループを防ぐ
    logger.info("  🤖 Gemini API呼び出し中（Google検索ツール有効）...")
    api_start = time.time()
    
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash-lite",
            temperature=0,
            google_api_key=settings.GOOGLE_API_KEY,
            max_retries=0,
        )
        resp = _invoke_with_retry(
            llm,
            prompt.format(company=state.company, location=state.location),
            tools=[GenAITool(google_search={})],
        )
        api_elapsed = time.time() - api_start
        logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
    except Exception as e:
        api_elapsed = time.time() - api_start
        logger.error(f"  ❌ API呼び出し失敗 ({api_elapsed:.2f}秒)")
        logger.error(f"  エラー: {type(e).__name__}: {str(e)[:200]}")
        raise

    # 応答からURLを抽出
    urls: list[str] = []
    
    # まず本文から全てのURLを抽出（最も信頼性が高い）
    # より厳密なURL正規表現を使用（不完全なURLを除外）
    url_pattern = r'https?://[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*(?:/[^\s<>"]*)?'
    content_urls = re.findall(url_pattern, resp.content)
    # リダイレクトURLと不完全なURLを除外
    def _is_valid_url(url: str) -> bool:
        """URLが有効かどうかを判定する."""
        # リダイレクトURLを除外
        if 'grounding-api-redirect' in url:
            return False
        # スキームとドメインを含む必要がある
        if url.count('/') < 2:
            return False
        # ドメインにドットを含む必要がある
        try:
            domain = url.split('//')[1].split('/')[0]
            if '.' not in domain:
                return False
            # 日本語文字や全角文字を含むURLを除外（不完全な抽出を防ぐ）
            if any(ord(c) > 127 for c in url):
                return False
        except (IndexError, AttributeError):
            return False
        return True
    
    content_urls = [url for url in content_urls if _is_valid_url(url)]
    
    if content_urls:
        urls.extend(content_urls)
        logger.info(f"  ✅ 本文から{len(content_urls)}個のURL抽出:")
        for url in content_urls[:5]:
            logger.info(f"     - {url}")
    
    # grounding由来URL（リダイレクトURLは使わない）
    try:
        reference_urls = [
            chunk["web"]["uri"]
            for chunk in resp.response_metadata["grounding_metadata"]["grounding_chunks"]
        ]
        # リダイレクトURLを除外
        direct_urls = [url for url in reference_urls if not url.startswith('https://vertexaisearch.cloud.google.com')]
        if direct_urls:
            logger.info(f"  ✅ Google検索から{len(direct_urls)}個の直接URL取得")
            urls.extend(direct_urls)
        else:
            logger.warning(f"  ⚠️ Google検索結果は全てリダイレクトURL（{len(reference_urls)}個）- スキップ")
    except Exception:  # noqa: BLE001
        logger.warning("  ⚠️ Google検索結果なし")
    
    logger.info(f"  取得したURL候補: {len(urls)}個")

    # 除外ドメイン設定に基づいて候補URLをフィルタ
    # サブドメインも含めて末尾一致で除外する
    def _is_excluded(url: str) -> bool:
        # EXCLUDE_DOMAINS は改行区切りの文字列 or リストを想定
        raw = settings.EXCLUDE_DOMAINS
        domains = [s.strip() for s in raw.splitlines() if s.strip()]
        return any(domain in url for domain in domains)

    filtered_urls = [u for u in urls if not _is_excluded(u)]
    excluded_count = len(urls) - len(filtered_urls)
    if excluded_count > 0:
        logger.info(f"  除外されたURL: {excluded_count}個")

    # 到達可能URLに正規化
    logger.info("  🌐 URL到達可能性チェック中...")
    state.urls = convert_accessable_urls(filtered_urls)
    
    node_elapsed = time.time() - node_start
    logger.info(f"  ✅ 最終URL候補: {len(state.urls)}個")
    for i, url in enumerate(state.urls[:5], 1):  # 最大5個まで表示
        logger.info(f"     {i}. {url}")
    if len(state.urls) > 5:
        logger.info(f"     ... 他{len(state.urls) - 5}個")
    logger.info(f"  ⏱️ ノード処理時間: {node_elapsed:.2f}秒")
    
    return state


def node_select_official_website(state: ExtractState) -> ExtractState:
    """候補URLから公式サイトを一つ選定して状態を更新する.

    Args:
        state: `urls` を含む状態。

    Returns:
        dict: `selected_url` を追加した状態。

    """
    node_start = time.time()
    logger.info("-" * 60)
    logger.info("[NODE 2/3] node_select_official_website - 公式サイト選定")
    logger.info(f"  候補URL数: {len(state.urls)}個")
    
    # URL候補が1個以下の場合、選定不要（最適化）
    if len(state.urls) <= 1:
        logger.info("  ℹ️ URL候補が1個以下のため選定をスキップします")
        logger.info("  ⏱️ ノード処理時間: 0.00秒（スキップ）")
        return state
    
    urls = state.urls
    web_context = ""
    
    logger.info("  🕷️ 各URLをクロール中（timeout=20秒）...")
    for i, url in enumerate(urls, 1):
        crawl_start = time.time()
        logger.info(f"     [{i}/{len(urls)}] {url}")
        markdown = crawl_markdown(url, timeout=20)
        crawl_elapsed = time.time() - crawl_start
        if not markdown:
            logger.warning(f"        ⚠️ クロール失敗またはタイムアウト ({crawl_elapsed:.2f}秒)")
            continue  # 失敗したURLはスキップ
        logger.info(f"        ✅ クロール完了 ({crawl_elapsed:.2f}秒, {len(markdown)}文字)")
        web_context += f"""# {url}\n{markdown}\n"""
    
    prompt = load_prompt(str(BASE_DIR / "agent/prompts/select_official.yaml"), encoding="utf-8")
    logger.debug("  ✅ プロンプトロード完了")
    
    logger.info("  🤖 Gemini API呼び出し中（公式サイト選定）...")
    api_start = time.time()
    
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash-lite",
            temperature=0,
            google_api_key=settings.GOOGLE_API_KEY,
            max_retries=0,
        ).with_structured_output(URLScoreList)
        resp: URLScoreList = _invoke_with_retry(
            llm,
            prompt.format(company=state.company, location=state.location, web_context=web_context),
        )
        api_elapsed = time.time() - api_start
        logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
    except Exception as e:
        api_elapsed = time.time() - api_start
        logger.error(f"  ❌ API呼び出し失敗 ({api_elapsed:.2f}秒)")
        logger.error(f"  エラー: {type(e).__name__}: {str(e)[:200]}")
        raise
    
    sorted_urls = sorted(resp.urls, key=lambda x: x.score, reverse=True)
    logger.info("  📊 URLスコアリング結果:")
    for i, url_score in enumerate(sorted_urls[:5], 1):
        logger.info(f"     {i}. {url_score.url} (スコア: {url_score.score})")

    def _is_excluded(url: str) -> bool:
        # EXCLUDE_DOMAINS は改行区切りの文字列 or リストを想定
        raw = settings.EXCLUDE_DOMAINS
        domains = [s.strip() for s in raw.splitlines() if s.strip()]
        return any(domain in url for domain in domains)

    state.urls = [url.url for url in sorted_urls if not _is_excluded(url.url)]
    
    node_elapsed = time.time() - node_start
    logger.info(f"  ✅ 選定されたURL: {len(state.urls)}個")
    logger.info(f"  ⏱️ ノード処理時間: {node_elapsed:.2f}秒")

    return state


def node_fetch_html(state: ExtractState) -> ExtractState:
    """選定URLのHTMLを取得し状態に格納する.

    Args:
        state: `selected_url` を含む状態。

    Returns:
        dict: `html` を追加した状態（失敗時は空文字）。

    """
    node_start = time.time()
    logger.info("-" * 60)
    logger.info("[NODE 3/3] node_fetch_html - 会社情報抽出")
    
    # URL候補が無い場合はエラーを発生させる（ValidationErrorを避けるため）
    if not state.urls:
        logger.warning("  ⚠️ URL候補が0個 - 抽出をスキップします")
        raise ValueError("URL候補が見つかりませんでした。会社情報を抽出できません。")
    
    url = state.urls.pop(0)
    logger.info(f"  対象URL: {url}")
    
    logger.info("  🕷️ Webページクロール中（depth=1, timeout=30秒）...")
    crawl_start = time.time()
    web_context = crawl_markdown(url, depth=1, timeout=30)
    crawl_elapsed = time.time() - crawl_start
    if not web_context:
        logger.warning(f"  ⚠️ クロール失敗またはタイムアウト ({crawl_elapsed:.2f}秒)")
        raise ValueError(f"URL {url} のクロールに失敗しました（タイムアウトまたはエラー）。")
    logger.info(f"  ✅ クロール完了 ({crawl_elapsed:.2f}秒, {len(web_context)}文字)")

    prompt = load_prompt(str(BASE_DIR / "agent/prompts/extract_contact.yaml"), encoding="utf-8")
    logger.debug("  ✅ プロンプトロード完了")
    
    logger.info("  🤖 Gemini API呼び出し中（会社情報抽出）...")
    logger.info(f"     必須業種: {state.required_businesses}")
    logger.info(f"     必須ジャンル: {state.required_genre}")
    api_start = time.time()
    
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash-lite",
            temperature=0,
            google_api_key=settings.GOOGLE_API_KEY,
            max_retries=0,
        ).with_structured_output(LLMCompanyInfo)
        resp: LLMCompanyInfo = _invoke_with_retry(
            llm,
            prompt.format(
                required_businesses=state.required_businesses,
                required_genre=state.required_genre,
                web_context=web_context,
            ),
        )
        api_elapsed = time.time() - api_start
        logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
        logger.info("  📋 抽出された情報:")
        logger.info(f"     会社名: {resp.company}")
        logger.info(f"     電話番号: {resp.tel}")
        logger.info(f"     住所: {resp.address}")
        logger.info(f"     URL: {resp.url}")
        logger.info(f"     お問い合わせURL: {resp.contact_url}")
    except Exception as e:
        api_elapsed = time.time() - api_start
        logger.error(f"  ❌ API呼び出し失敗 ({api_elapsed:.2f}秒)")
        logger.error(f"  エラー: {type(e).__name__}: {str(e)[:200]}")
        raise

    state.company_info = resp.model_dump()
    
    node_elapsed = time.time() - node_start
    logger.info(f"  ⏱️ ノード処理時間: {node_elapsed:.2f}秒")
    
    return state
