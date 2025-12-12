import json
import re
import time
from typing import Literal, Optional

from google import genai
from google.api_core.exceptions import ResourceExhausted
from google.genai import types as genai_types
from google.ai.generativelanguage_v1beta.types import Tool as GenAITool
from langchain_core.prompts.loading import load_prompt
from langchain_core.messages import HumanMessage
from langchain_google_genai import ChatGoogleGenerativeAI
from pydantic import BaseModel, Field, create_model, field_validator

from agent.state import ExtractState
from agent.tools import (
    get_check_url_accessibility_declaration,
    get_crawl_footer_links_declaration,
    get_crawl_website_declaration,
    get_report_company_info_declaration,
    get_report_url_scores_declaration,
    get_validate_company_info_declaration,
    handle_function_call,
)
from models.schemas import CompanyInfo, LLMCompanyInfo, URLScoreList
from models.settings import BASE_DIR, settings
from utils.crawl4ai_util import crawl_markdown
from utils.net import convert_accessable_urls
from utils.logger import get_logger

RETRY_DELAY_SECONDS = 10.0  # ResourceExhausted時は常に10秒待機
RETRY_ATTEMPTS = 9  # 最大10回試行 (retries + 1)
API_CALL_INTERVAL_SECONDS = 5.0  # API呼び出し間の間隔を5秒に増加（安全マージン）
DEFAULT_GEMINI_MODEL = "gemini-2.5-flash"

logger = get_logger()


def _invoke_with_retry(operation, *, retries: int = RETRY_ATTEMPTS):
    """任意のGemini API呼び出しを最大retries回再試行（エクスポネンシャルバックオフ）で実行."""
    attempts = retries + 1
    for attempt in range(attempts):
        try:
            return operation()
        except ResourceExhausted as exc:
            if attempt == retries:
                error_msg = str(exc)
                logger.error(f"  ❌ ResourceExhaustedエラー（最終試行失敗）: {error_msg[:300]}")
                if "quota" in error_msg.lower() or "limit" in error_msg.lower():
                    logger.error("  ⚠️ クォータ/制限関連のエラーの可能性があります")
                else:
                    logger.warning("  ⚠️ 一時的なレート制限の可能性があります（クォータ超過ではない可能性）")
                raise
            backoff_delay = RETRY_DELAY_SECONDS
            logger.warning(
                "  ⚠️ ResourceExhaustedエラー (attempt %s/%s). %s秒後に再試行します…",
                attempt + 1,
                attempts,
                backoff_delay,
            )
            logger.debug(f"  エラー詳細: {str(exc)[:200]}")
            time.sleep(backoff_delay)
        except Exception as exc:
            error_type = type(exc).__name__
            error_msg = str(exc)
            logger.error(f"  ❌ {error_type}エラー: {error_msg[:300]}")
            import traceback
            logger.debug(f"  トレースバック: {traceback.format_exc()}")
            raise


def _wait_between_api_calls():
    """API呼び出し間の間隔を空ける."""
    logger.debug(f"  ⏳ API呼び出し間隔のため{API_CALL_INTERVAL_SECONDS}秒待機中...")
    time.sleep(API_CALL_INTERVAL_SECONDS)


def _load_json_from_text(text: str) -> Optional[dict]:
    """テキストから最初のJSONオブジェクトまたは配列を抽出して辞書に変換."""
    if not text:
        return None

    pattern_object = r"```json\s*(\{.*?\})\s*```"
    pattern_array = r"```json\s*(\[.*?\])\s*```"
    match = re.search(pattern_object, text, re.DOTALL) or re.search(pattern_array, text, re.DOTALL)
    json_candidate = None
    if match:
        json_candidate = match.group(1)
    else:
        start_idx = text.find("{")
        if start_idx == -1:
            start_idx = text.find("[")
        if start_idx != -1:
            brace = text[start_idx]
            stack = 0
            for i in range(start_idx, len(text)):
                char = text[i]
                if char == brace:
                    stack += 1
                elif (brace == "{" and char == "}") or (brace == "[" and char == "]"):
                    stack -= 1
                    if stack == 0:
                        json_candidate = text[start_idx : i + 1]
                        break
    if not json_candidate:
        return None
    try:
        return json.loads(json_candidate)
    except json.JSONDecodeError:
        return None


def _normalize_url_scores_payload(data: Optional[dict | list]) -> Optional[dict]:
    if data is None:
        return None
    if isinstance(data, list):
        return {"urls": data}
    if isinstance(data, dict) and "urls" in data:
        return data
    return None


def _create_gemini_client() -> genai.Client:
    return genai.Client(api_key=settings.GOOGLE_API_KEY)


def _build_user_content(text: str) -> genai_types.Content:
    return genai_types.Content(
        role="user",
        parts=[genai_types.Part.from_text(text=text)],
    )


def _content_to_text(content: Optional[genai_types.Content]) -> str:
    if not content:
        return ""
    parts = content.parts or []
    return "".join(part.text or "" for part in parts if part.text)


def _iter_function_calls(content: Optional[genai_types.Content]):
    if not content or not content.parts:
        return []
    return [
        part.function_call
        for part in content.parts
        if part.function_call is not None
    ]


def _append_function_response_message(
    messages: list[genai_types.Content], function_name: str, response_data: dict
):
    messages.append(
        genai_types.Content(
            role="tool",
            parts=[
                genai_types.Part.from_function_response(
                    name=function_name,
                    response=response_data,
                )
            ],
        )
    )


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
    logger.info("  🔍 Google Searchツール（Grounding API）を使用します")
    
    client = _create_gemini_client()
    google_search_tool = genai_types.Tool(google_search=genai_types.GoogleSearch())
    config = genai_types.GenerateContentConfig(
        tools=[google_search_tool],
        temperature=0,
    )
    prompt_text = prompt.format(company=state.company, location=state.location)

    urls: list[str] = []
    MAX_SEARCH_RETRIES = 3  # URL取得のリトライ回数

    for attempt in range(MAX_SEARCH_RETRIES):
        logger.info(f"  🔄 検索実行 (試行 {attempt + 1}/{MAX_SEARCH_RETRIES})")
        api_start = time.time()
        
        try:
            logger.info("  🔧 Google Searchツールを有効化")
            resp = _invoke_with_retry(
                    lambda: client.models.generate_content(
                        model=DEFAULT_GEMINI_MODEL,
                    contents=[_build_user_content(prompt_text)],
                    config=config,
                )
            )
            api_elapsed = time.time() - api_start
            actual_model = getattr(resp, "model_version", "不明")
            logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
            logger.info(f"  📊 使用モデル: 実際={actual_model}")

            logger.debug("  ⏳ Google Searchツール使用後の追加待機時間（1秒）...")
            time.sleep(1.0)
            _wait_between_api_calls()
        except Exception as e:
            api_elapsed = time.time() - api_start
            logger.error(f"  ❌ API呼び出し失敗 ({api_elapsed:.2f}秒)")
            logger.error(f"  エラー: {type(e).__name__}: {str(e)[:200]}")
            if attempt == MAX_SEARCH_RETRIES - 1:
                raise
            time.sleep(5.0) # エラー時の待機
            continue

        # 応答からURLを抽出
        candidate = resp.candidates[0] if resp.candidates else None
        resp_text = resp.text or _content_to_text(candidate.content if candidate else None)
        
        # まず本文から全てのURLを抽出（最も信頼性が高い）
        # より厳密なURL正規表現を使用（不完全なURLを除外）
        url_pattern = r'https?://[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*(?:/[^\s<>"]*)?'
        content_urls = re.findall(url_pattern, resp_text)
        
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
        
        # grounding由来URL（リダイレクトURLから実際のURLを抽出）
        try:
            reference_urls = []
            if candidate and getattr(candidate, "grounding_metadata", None):
                grounding_metadata = candidate.grounding_metadata
                chunks = getattr(grounding_metadata, "grounding_chunks", None) or []
                logger.info(f"  📋 grounding_chunks数: {len(chunks)}")
                for i, chunk in enumerate(chunks[:3], 1):
                    web_info = getattr(chunk, "web", None)
                    if web_info:
                        logger.info(f"    [chunk {i}] web.uri: {getattr(web_info, 'uri', 'N/A')}")
                reference_urls = [
                    getattr(chunk.web, "uri", "")
                    for chunk in chunks
                    if getattr(chunk, "web", None)
                ]
            
            # 全てのURLをログに出力
            logger.info(f"  📋 取得したreference_urls ({len(reference_urls)}個):")
            for i, url in enumerate(reference_urls, 1):
                logger.info(f"    {i}. {url}")
            
            direct_urls = []
            if candidate and getattr(candidate, "grounding_metadata", None):
                chunks = getattr(candidate.grounding_metadata, "grounding_chunks", None) or []
                for chunk in chunks:
                    web_info = getattr(chunk, "web", None)
                    if not web_info:
                        continue
                    uri = getattr(web_info, "uri", "")
                    title = getattr(web_info, "title", "")
                    if uri.startswith("https://vertexaisearch.cloud.google.com") and title:
                        if not title.startswith("http"):
                            actual_url = f"https://{title.strip()}"
                        else:
                            actual_url = title.strip()
                        direct_urls.append(actual_url)
                        logger.info(f"  ✅ リダイレクトURLから抽出（title使用）: {actual_url}")
                    else:
                        direct_urls.append(uri)
                        logger.debug(f"  直接URL: {uri}")
            
            if direct_urls:
                direct_count = len([u for u in reference_urls if not u.startswith('https://vertexaisearch.cloud.google.com')])
                redirect_extracted_count = len(direct_urls) - direct_count
                logger.info(f"  ✅ Google検索から{len(direct_urls)}個のURL取得（直接: {direct_count}個, リダイレクトから抽出: {redirect_extracted_count}個）")
                urls.extend(direct_urls)
            else:
                logger.warning(f"  ⚠️ Google検索結果からURLを抽出できませんでした（{len(reference_urls)}個）")
        except Exception as e:
            logger.error(f"  ❌ Google検索結果の処理に失敗: {type(e).__name__}: {str(e)}")
            import traceback
            logger.debug(f"  トレースバック: {traceback.format_exc()}")
        
        # URLが見つかった場合はループを抜ける
        if urls:
            break
        
        logger.warning(f"  ⚠️ URL候補が見つかりませんでした (試行 {attempt + 1}/{MAX_SEARCH_RETRIES})")
        if attempt < MAX_SEARCH_RETRIES - 1:
            logger.info("  🔄 再検索のため待機中...")
            time.sleep(2.0)

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
    
    logger.info(f"  🕷️ 各URLをクロール中（timeout=10秒, 計{len(urls)}件）...")
    for i, url in enumerate(urls, 1):
        crawl_start = time.time()
        logger.info(f"     [{i}/{len(urls)}] {url}")
        markdown = crawl_markdown(url, timeout=10)  # 20秒 → 10秒に短縮
        crawl_elapsed = time.time() - crawl_start
        if not markdown:
            logger.warning(f"        ⚠️ クロール失敗またはタイムアウト ({crawl_elapsed:.2f}秒)")
            continue  # 失敗したURLはスキップ
        logger.info(f"        ✅ クロール完了 ({crawl_elapsed:.2f}秒, {len(markdown)}文字)")
        # コンテキストサイズを制限（パフォーマンス改善）
        # 各URLのクロール結果を10,000文字までに制限
        if len(markdown) > 10000:
            markdown = markdown[:10000]
            logger.debug(f"        ⚠️ コンテキストサイズを制限: {len(markdown)}文字（10,000文字まで）")
        web_context += f"""# {url}\n{markdown}\n"""
    if not web_context:
        logger.warning("  ⚠️ Webコンテキストが空のため、公式サイト選定をスキップします")
        raise ValueError("候補URLのクロールにすべて失敗し、Webコンテキストを取得できませんでした。")

    prompt = load_prompt(str(BASE_DIR / "agent/prompts/select_official.yaml"), encoding="utf-8")
    logger.debug("  ✅ プロンプトロード完了")
    
    logger.info("  🤖 Gemini API呼び出し中（公式サイト選定）...")
    api_start = time.time()
    client = _create_gemini_client()
    tools = [
        genai_types.Tool(
            function_declarations=[
                get_crawl_website_declaration(),
                get_crawl_footer_links_declaration(),
                get_report_url_scores_declaration(),
            ]
        )
    ]
    config = genai_types.GenerateContentConfig(
        tools=tools,
        temperature=0,
    )
    messages = [
        _build_user_content(
            prompt.format(
                company=state.company,
                location=state.location,
                web_context=web_context,
            )
        )
    ]
    MAX_REPORT_RETRIES = 2
    max_iterations = MAX_REPORT_RETRIES + 1  # 初回 + 最大2回のリトライ
    url_score_payload: Optional[dict] = None
    report_retry_count = 0
    
    try:
        for iteration in range(max_iterations):
            resp = _invoke_with_retry(
                lambda: client.models.generate_content(
                    model=DEFAULT_GEMINI_MODEL,
                    contents=messages,
                    config=config,
                )
            )
            candidate = resp.candidates[0] if resp.candidates else None
            if not candidate:
                raise ValueError("LLMの応答が空でした。")
            tool_calls = _iter_function_calls(candidate.content)
            messages.append(candidate.content)
            
            # report_url_scores が生成されたらそれを採用
            report_call = next((fc for fc in tool_calls if fc.name == "report_url_scores"), None)
            if report_call:
                url_score_payload = _normalize_url_scores_payload(dict(report_call.args or {}))
                break
            
            fallback_handled = False
            if not tool_calls:
                fallback_json = _load_json_from_text(_content_to_text(candidate.content))
                url_score_payload = _normalize_url_scores_payload(fallback_json)
                if url_score_payload:
                    break
                fallback_handled = True
            
            if tool_calls and not fallback_handled:
                for fc in tool_calls:
                    if fc.name == "report_url_scores":
                        continue
                    result = handle_function_call(fc.name, dict(fc.args or {}))
                    _append_function_response_message(messages, fc.name, result)
                _wait_between_api_calls()

            if url_score_payload:
                break

            if iteration < max_iterations - 1:
                report_retry_count += 1
                reminder = _build_user_content(
                    "上記の情報を踏まえて公式サイトのみを対象とし、必ず `report_url_scores` 関数を呼び出してスコア付きURL一覧を出力してください。"
                )
                messages.append(reminder)
                logger.info(f"  🔁 report_url_scoresの再リクエスト ({report_retry_count}/{MAX_REPORT_RETRIES})")

        else:
            logger.error("  ❌ report_url_scoresが生成されませんでした")
            # デバッグ用にレスポンス内容を出力
            raw_response = _content_to_text(candidate.content)
            logger.error(f"  🔍 LLM生応答 (先頭1000文字): {raw_response[:1000]}")
            raise ValueError("LLMがURLスコアを出力できませんでした。")
    except Exception as e:
        api_elapsed = time.time() - api_start
        logger.error(f"  ❌ API呼び出し失敗 ({api_elapsed:.2f}秒)")
        logger.error(f"  エラー: {type(e).__name__}: {str(e)[:200]}")
        raise
    
    if not url_score_payload:
        raise ValueError("LLMの応答からURLスコアを取得できませんでした。")
    
    resp_scores = URLScoreList.model_validate(url_score_payload)
    sorted_urls = sorted(resp_scores.urls, key=lambda x: x.score, reverse=True)
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


def _split_text_into_chunks(text: str, chunk_size: int = 8000) -> list[str]:
    """テキストを指定した文字数で分割する."""
    if not text:
        return [""]
    return [text[i : i + chunk_size] for i in range(0, len(text), chunk_size)]


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
    
    logger.info("  🕷️ Webページクロール中（depth=0, timeout=10秒）...")
    crawl_start = time.time()
    try:
        # depth=0に変更（ディープクロールは時間がかかりすぎるため）
        # タイムアウトを10秒に短縮（パフォーマンス改善）
        web_context = crawl_markdown(url, depth=0, timeout=10)  # 30秒 → 10秒に短縮
        crawl_elapsed = time.time() - crawl_start
        if not web_context:
            logger.warning(f"  ⚠️ クロール失敗またはタイムアウト ({crawl_elapsed:.2f}秒)")
            logger.warning(f"  ⚠️ URL: {url}")
            raise ValueError(f"URL {url} のクロールに失敗しました（タイムアウトまたはエラー）。")
        logger.info(f"  ✅ クロール完了 ({crawl_elapsed:.2f}秒, {len(web_context)}文字)")
    except Exception as e:
        crawl_elapsed = time.time() - crawl_start
        logger.error(f"  ❌ クロール例外発生 ({crawl_elapsed:.2f}秒)")
        logger.error(f"  エラー: {type(e).__name__}: {str(e)[:200]}")
        import traceback
        logger.debug(f"  トレースバック: {traceback.format_exc()}")
        raise ValueError(f"URL {url} のクロールに失敗しました（タイムアウトまたはエラー）。")

    # 構造化出力では全コンテキストを一度に処理
    # web_context_chunks = _split_text_into_chunks(web_context, chunk_size=8000)
    # current_chunk_index = 0
    
    prompt = load_prompt(str(BASE_DIR / "agent/prompts/extract_contact.yaml"), encoding="utf-8")
    logger.debug("  ✅ プロンプトロード完了")
    
    logger.info("  🤖 Gemini API呼び出し中（会社情報抽出）...")
    logger.info(f"     必須業種: {state.required_businesses}")
    logger.info(f"     必須ジャンル: {state.required_genre}")
    api_start = time.time()
    
    # 構造化出力用のPydanticモデル定義
    class StructuredCompanyInfo(BaseModel):
        """構造化出力用の会社情報モデル"""
        company: Optional[str] = Field(None, description="会社名。株式会社/有限会社等を含む正式名称")
        tel: Optional[str] = Field(None, description="電話番号。半角数字とハイフンのみの形式")
        address: Optional[str] = Field(None, description="住所。都道府県を含む完全な住所")
        first_name: Optional[str] = Field(None, description="担当者名・代表者名")
        url: Optional[str] = Field(None, description="公式サイトのURL")
        contact_url: Optional[str] = Field(None, description="お問い合わせページのURL")

    prompt_content = prompt.format(
        web_context=web_context,
        chunk_info="完全なコンテンツ",
    )
    
    client = _create_gemini_client()
    

    config = genai_types.GenerateContentConfig(
        response_mime_type="application/json",
        response_schema=StructuredCompanyInfo.model_json_schema(),
        temperature=0.3,
    )
    messages = [_build_user_content(prompt_content)]
    
    try:
        resp = _invoke_with_retry(
            lambda: client.models.generate_content(
                model=DEFAULT_GEMINI_MODEL,
                contents=messages,
                config=config,
            )
        )
        # 構造化出力から直接データを取得
        candidate = resp.candidates[0] if resp.candidates else None
        if not candidate:
            raise ValueError("LLMの応答が空でした。")
        
        response_text = _content_to_text(candidate.content)
        company_info_payload = json.loads(response_text)
        
    except Exception as e:
        api_elapsed = time.time() - api_start
        logger.error(f"  ❌ API呼び出し失敗 ({api_elapsed:.2f}秒)")
        logger.error(f"  エラー: {type(e).__name__}: {str(e)[:200]}")
        raise
    
    if not company_info_payload:
        raise ValueError("LLMの応答から会社情報を取得できませんでした。")
    
    resp_info = StructuredCompanyInfo.model_validate(company_info_payload)
    logger.info("  ✅ 会社情報の構造化に成功")
    logger.info(f"     会社名: {resp_info.company}")
    logger.info(f"     電話番号: {resp_info.tel}")
    logger.info(f"     住所: {resp_info.address}")
    logger.info(f"     URL: {resp_info.url}")
    logger.info(f"     お問い合わせURL: {resp_info.contact_url}")
    # 業種・ジャンルはまだないので出力しない（後で追加）
    
    company_info_dict = resp_info.model_dump()
    
    # urlがNoneの場合は、実際にクロールしたURLを使用
    if not company_info_dict.get("url"):
        company_info_dict["url"] = url
        logger.info(f"  ⚠️ LLMがurlを抽出できなかったため、クロールしたURLを使用: {url}")
    
    # businessとgenreは入力データのrequired_businessesとrequired_genreから取得（LLMの誤抽出を避けるため）
    if state.required_businesses and len(state.required_businesses) > 0:
        company_info_dict["business"] = state.required_businesses[0]
        logger.info(f"  📝 businessを入力データから取得: {company_info_dict['business']}")
    else:
        company_info_dict["business"] = ""
        logger.info("  📝 businessを入力データから取得できませんでした（空文字を設定）")
    
    if state.required_genre and len(state.required_genre) > 0:
        company_info_dict["genre"] = state.required_genre[0]
        logger.info(f"  📝 genreを入力データから取得: {company_info_dict['genre']}")
    else:
        company_info_dict["genre"] = ""
        logger.info("  📝 genreを入力データから取得できませんでした（空文字を設定）")
    
    state.company_info = company_info_dict
    
    node_elapsed = time.time() - node_start
    logger.info(f"  ⏱️ ノード処理時間: {node_elapsed:.2f}秒")
    
    return state
