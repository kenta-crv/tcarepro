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

RETRY_DELAY_SECONDS = 8.0  # リトライ時の待機時間を8秒に増加
RETRY_ATTEMPTS = 1  # 1回リトライ = 最大2回試行
API_CALL_INTERVAL_SECONDS = 5.0  # API呼び出し間の間隔を5秒に増加（RPM=15の場合、最低4秒必要）

logger = get_logger()


def _invoke_with_retry(llm, prompt_str: str, *, retries: int = RETRY_ATTEMPTS, **invoke_kwargs):
    """Gemini API呼び出しを最大retries回再試行（エクスポネンシャルバックオフ）で実行."""
    attempts = retries + 1
    for attempt in range(attempts):
        try:
            return llm.invoke(prompt_str, **invoke_kwargs)
        except ResourceExhausted as exc:
            if attempt == retries:
                # 最後の試行でも失敗した場合、エラーメッセージを詳細にログ出力
                error_msg = str(exc)
                logger.error(f"  ❌ ResourceExhaustedエラー（最終試行失敗）: {error_msg[:300]}")
                # エラーメッセージにクォータ関連のキーワードが含まれているか確認
                if "quota" in error_msg.lower() or "limit" in error_msg.lower():
                    logger.error("  ⚠️ クォータ/制限関連のエラーの可能性があります")
                else:
                    logger.warning("  ⚠️ 一時的なレート制限の可能性があります（クォータ超過ではない可能性）")
                raise
            # エクスポネンシャルバックオフ: 2^attempt * RETRY_DELAY_SECONDS
            backoff_delay = RETRY_DELAY_SECONDS * (2 ** attempt)
            logger.warning(
                "  ⚠️ ResourceExhaustedエラー (attempt %s/%s). %s秒待機して再試行します…",
                attempt + 1,
                attempts,
                backoff_delay,
            )
            logger.debug(f"  エラー詳細: {str(exc)[:200]}")
            time.sleep(backoff_delay)
        except Exception:
            raise


def _wait_between_api_calls():
    """API呼び出し間の間隔を空ける."""
    logger.debug(f"  ⏳ API呼び出し間隔のため{API_CALL_INTERVAL_SECONDS}秒待機中...")
    time.sleep(API_CALL_INTERVAL_SECONDS)


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
    api_start = time.time()
    
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash",
            temperature=0,
            google_api_key=settings.GOOGLE_API_KEY,
            max_retries=0,
        )
        # Google Searchツール使用時は追加の待機時間を設定（Grounding APIのレート制限を考慮）
        google_search_tool = GenAITool(google_search={})
        resp = _invoke_with_retry(
            llm,
            prompt.format(company=state.company, location=state.location),
            tools=[google_search_tool],
        )
        api_elapsed = time.time() - api_start
        
        # 実際に使用されたモデル名をログに記録
        actual_model = "不明"
        try:
            if hasattr(resp, 'response_metadata') and resp.response_metadata:
                # response_metadataからモデル名を取得
                metadata = resp.response_metadata
                if isinstance(metadata, dict):
                    actual_model = metadata.get('model_name', metadata.get('model', '不明'))
                elif hasattr(metadata, 'model_name'):
                    actual_model = metadata.model_name
                elif hasattr(metadata, 'model'):
                    actual_model = metadata.model
        except Exception:
            pass
        
        logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
        specified_model = getattr(llm, 'model', getattr(llm, 'model_name', 'gemini-2.0-flash'))
        logger.info(f"  📊 使用モデル: 指定={specified_model}, 実際={actual_model}")
        
        # Google Searchツール使用時の処理
        # 公式ドキュメント: https://ai.google.dev/gemini-api/docs/google-search?hl=ja
        # Google Searchツールは内部的に複数の検索クエリを実行する可能性があるため、
        # 通常のAPI呼び出しよりも長い待機時間を設定
        # ただし、公式ドキュメントには固有のレート制限の記載はない
        logger.debug("  ⏳ Google Searchツール使用後の追加待機時間（2秒）...")
        time.sleep(2.0)
        _wait_between_api_calls()  # API呼び出し間の間隔（通常の5秒）
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
    
    # grounding由来URL（リダイレクトURLから実際のURLを抽出）
    try:
        # レスポンスメタデータをログに出力（デバッグ用）
        logger.debug("  📋 response_metadata構造:")
        logger.debug(f"    response_metadata keys: {list(resp.response_metadata.keys()) if isinstance(resp.response_metadata, dict) else 'not a dict'}")
        
        if isinstance(resp.response_metadata, dict) and "grounding_metadata" in resp.response_metadata:
            grounding_metadata = resp.response_metadata["grounding_metadata"]
            logger.debug(f"    grounding_metadata keys: {list(grounding_metadata.keys()) if isinstance(grounding_metadata, dict) else 'not a dict'}")
            
            if isinstance(grounding_metadata, dict) and "grounding_chunks" in grounding_metadata:
                chunks = grounding_metadata["grounding_chunks"]
                logger.info(f"  📋 grounding_chunks数: {len(chunks)}")
                for i, chunk in enumerate(chunks[:3], 1):  # 最初の3個のみ詳細ログ
                    logger.info(f"    [chunk {i}] keys: {list(chunk.keys()) if isinstance(chunk, dict) else 'not a dict'}")
                    if isinstance(chunk, dict) and "web" in chunk:
                        web_info = chunk["web"]
                        logger.info(f"      web keys: {list(web_info.keys()) if isinstance(web_info, dict) else 'not a dict'}")
                        if isinstance(web_info, dict):
                            logger.info(f"      web.uri: {web_info.get('uri', 'N/A')}")
                            # webオブジェクトの全フィールドをログに出力
                            import json
                            logger.info(f"      web全体 (JSON): {json.dumps(web_info, ensure_ascii=False, indent=2)}")
        
        reference_urls = [
            chunk["web"]["uri"]
            for chunk in resp.response_metadata["grounding_metadata"]["grounding_chunks"]
        ]
        
        # 全てのURLをログに出力
        logger.info(f"  📋 取得したreference_urls ({len(reference_urls)}個):")
        for i, url in enumerate(reference_urls, 1):
            logger.info(f"    {i}. {url}")
        
        # リダイレクトURLから実際のURLを抽出（titleフィールドからドメイン名を取得）
        direct_urls = []
        for i, chunk in enumerate(resp.response_metadata["grounding_metadata"]["grounding_chunks"]):
            uri = chunk["web"]["uri"]
            web_info = chunk["web"]
            
            if uri.startswith('https://vertexaisearch.cloud.google.com'):
                # リダイレクトURLの場合、titleフィールドからドメイン名を取得
                if "title" in web_info and web_info["title"]:
                    domain = web_info["title"].strip()
                    # ドメイン名からURLを構築
                    if domain and not domain.startswith('http'):
                        actual_url = f"https://{domain}"
                        direct_urls.append(actual_url)
                        logger.info(f"  ✅ リダイレクトURLから抽出（title使用）: {actual_url}")
                    else:
                        logger.warning(f"  ⚠️ titleフィールドが無効: {domain}")
                else:
                    logger.warning(f"  ⚠️ titleフィールドが見つかりません: {uri[:100]}")
            else:
                # 直接URL
                direct_urls.append(uri)
                logger.debug(f"  直接URL: {uri}")
        
        if direct_urls:
            direct_count = len([u for u in reference_urls if not u.startswith('https://vertexaisearch.cloud.google.com')])
            redirect_extracted_count = len(direct_urls) - direct_count
            logger.info(f"  ✅ Google検索から{len(direct_urls)}個のURL取得（直接: {direct_count}個, リダイレクトから抽出: {redirect_extracted_count}個）")
            urls.extend(direct_urls)
        else:
            logger.warning(f"  ⚠️ Google検索結果からURLを抽出できませんでした（{len(reference_urls)}個）")
    except Exception as e:  # noqa: BLE001
        logger.error(f"  ❌ Google検索結果の処理に失敗: {type(e).__name__}: {str(e)}")
        import traceback
        logger.debug(f"  トレースバック: {traceback.format_exc()}")
    
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
            model="gemini-2.0-flash",
            temperature=0,
            google_api_key=settings.GOOGLE_API_KEY,
            max_retries=0,
        ).with_structured_output(URLScoreList)
        resp: URLScoreList = _invoke_with_retry(
            llm,
            prompt.format(company=state.company, location=state.location, web_context=web_context),
        )
        api_elapsed = time.time() - api_start
        
        # 実際に使用されたモデル名をログに記録
        actual_model = "不明"
        try:
            # with_structured_outputを使っている場合、元のレスポンスを取得
            if hasattr(resp, 'response_metadata') and resp.response_metadata:
                metadata = resp.response_metadata
                if isinstance(metadata, dict):
                    actual_model = metadata.get('model_name', metadata.get('model', '不明'))
                elif hasattr(metadata, 'model_name'):
                    actual_model = metadata.model_name
                elif hasattr(metadata, 'model'):
                    actual_model = metadata.model
        except Exception:
            pass
        
        logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
        # with_structured_outputを使っている場合、元のllmオブジェクトを取得
        base_llm = llm if not hasattr(llm, 'llm') else llm.llm
        specified_model = getattr(base_llm, 'model', getattr(base_llm, 'model_name', 'gemini-2.0-flash'))
        logger.info(f"  📊 使用モデル: 指定={specified_model}, 実際={actual_model}")
        _wait_between_api_calls()  # API呼び出し間の間隔
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
    
    logger.info("  🕷️ Webページクロール中（depth=0, timeout=30秒）...")
    crawl_start = time.time()
    try:
        # depth=0に変更（ディープクロールは時間がかかりすぎるため）
        web_context = crawl_markdown(url, depth=0, timeout=30)
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

    prompt = load_prompt(str(BASE_DIR / "agent/prompts/extract_contact.yaml"), encoding="utf-8")
    logger.debug("  ✅ プロンプトロード完了")
    
    logger.info("  🤖 Gemini API呼び出し中（会社情報抽出）...")
    logger.info(f"     必須業種: {state.required_businesses}")
    logger.info(f"     必須ジャンル: {state.required_genre}")
    api_start = time.time()
    
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.0-flash",
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
        
        # 実際に使用されたモデル名をログに記録
        actual_model = "不明"
        try:
            # with_structured_outputを使っている場合、元のレスポンスを取得
            if hasattr(resp, 'response_metadata') and resp.response_metadata:
                metadata = resp.response_metadata
                if isinstance(metadata, dict):
                    actual_model = metadata.get('model_name', metadata.get('model', '不明'))
                elif hasattr(metadata, 'model_name'):
                    actual_model = metadata.model_name
                elif hasattr(metadata, 'model'):
                    actual_model = metadata.model
        except Exception:
            pass
        
        logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
        # with_structured_outputを使っている場合、元のllmオブジェクトを取得
        base_llm = llm if not hasattr(llm, 'llm') else llm.llm
        specified_model = getattr(base_llm, 'model', getattr(base_llm, 'model_name', 'gemini-2.0-flash'))
        logger.info(f"  📊 使用モデル: 指定={specified_model}, 実際={actual_model}")
        # 最後のAPI呼び出しなので間隔は不要
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

    # LLMの応答を辞書に変換
    company_info_dict = resp.model_dump()
    
    # urlがNoneの場合は、実際にクロールしたURLを使用
    if not company_info_dict.get("url"):
        company_info_dict["url"] = url
        logger.info(f"  ⚠️ LLMがurlを抽出できなかったため、クロールしたURLを使用: {url}")
    
    state.company_info = company_info_dict
    
    node_elapsed = time.time() - node_start
    logger.info(f"  ⏱️ ノード処理時間: {node_elapsed:.2f}秒")
    
    return state
