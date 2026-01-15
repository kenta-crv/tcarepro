import re
import time

from google.genai.types import Tool as GenAITool, GoogleSearch
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
API_CALL_INTERVAL_SECONDS = 2.0  # API呼び出し間の間隔（秒）

logger = get_logger()


# -----------------------------------------------------------------------------
# Company matching helpers
# -----------------------------------------------------------------------------
# NOTE:
# - We must avoid false positives where a different company is incorrectly accepted.
# - Therefore we only allow "corporate designator missing" relaxation when the
#   input company name uses prefix-style designator (e.g., "株式会社◯◯", "合同会社◯◯").
# - We additionally require location consistency (prefecture + if available city/ward).
PREFECTURES = [
    "北海道","青森県","岩手県","宮城県","秋田県","山形県","福島県",
    "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈川県",
    "新潟県","富山県","石川県","福井県","山梨県","長野県",
    "岐阜県","静岡県","愛知県","三重県",
    "滋賀県","京都府","大阪府","兵庫県","奈良県","和歌山県",
    "鳥取県","島根県","岡山県","広島県","山口県",
    "徳島県","香川県","愛媛県","高知県",
    "福岡県","佐賀県","長崎県","熊本県","大分県","宮崎県","鹿児島県","沖縄県",
]

LEGAL_DESIGNATORS_PREFIX = [
    # 会社法
    "株式会社",
    "合同会社",
    "合名会社",
    "合資会社",
    "特例有限会社",
    "有限会社",
    # その他（法人格）
    "相互会社",
    "一般社団法人",
    "一般財団法人",
    "公益社団法人",
    "公益財団法人",
    "NPO法人",
    "特定非営利活動法人",
    "医療法人",
    "社会医療法人",
    "社会福祉法人",
    "学校法人",
    "宗教法人",
    "更生保護法人",
    "地方公共団体",
    "独立行政法人",
    "国立大学法人",
    "弁護士法人",
    "税理士法人",
    "監査法人",
    "司法書士法人",
    "農事組合法人",
    "農業協同組合",
    "消費生活協同組合",
    "労働組合",
    "管理組合法人",
]

LEGAL_DESIGNATORS_SUFFIX = [
    # 「後株」系（サイト上で頻出）
    "株式会社",
    # 必要が出たらここに追加（例：有限会社 等）
]

_KABU_ABBREV_RE = re.compile(r"(?:㈱|[（(]\s*株\s*[)）])")

def _normalize_company_designators(name: str) -> str:
    """会社形態の略記を正規化する（表示揺れ吸収用）.

    対象:
      - ㈱, （株）, (株)  → 株式会社
    """
    if not name:
        return name
    s = name.strip()
    s = _KABU_ABBREV_RE.sub("株式会社", s)
    # 連続スペースを1つに
    s = re.sub(r"\s+", " ", s)
    return s


def _strip_spaces(s: str) -> str:
    return re.sub(r"\s+", "", s or "")


def _analyze_company_name(name: str) -> dict:

    def _normalize_corp_abbrev(s: str) -> str:
        # Common abbreviations: (株),(有), ㈱,㈲, full-width parentheses too.
        if not s:
            return ""
        t = str(s)
        t = t.replace("㈱", "株式会社").replace("㈲", "有限会社")
        t = re.sub(r"[（(]\s*株\s*[)）]", "株式会社", t)
        t = re.sub(r"[（(]\s*有\s*[)）]", "有限会社", t)
        return t

    """会社名を (法人種別, 位置, 本体名称) に分解する.

    返却キーは既存ロジック互換にしている:
      - raw: 正規化後の原文
      - no_space: 空白除去版
      - designator: 法人種別（株式会社/合同会社...） or None
      - position: 'prefix' / 'suffix' / None
      - core: 法人種別を除いた名称（英数字は小文字化）
      - has_designator: bool
    """
    if not name:
        return {
            "raw": "",
            "no_space": "",
            "designator": None,
            "position": None,
            "core": "",
            "has_designator": False,
        }

    normalized = _normalize_company_designators(name)
    raw = normalized.strip()
    no_space = _strip_spaces(raw)

    # prefix
    for d in LEGAL_DESIGNATORS_PREFIX:
        if raw.startswith(d):
            core = raw[len(d):].strip()
            return {
                "raw": raw,
                "no_space": no_space,
                "designator": d,
                "position": "prefix",
                "core": _strip_spaces(core).lower(),
                "has_designator": True,
            }

    # suffix（後株）
    for d in LEGAL_DESIGNATORS_SUFFIX:
        if raw.endswith(d) and len(raw) > len(d):
            core = raw[:-len(d)].strip()
            return {
                "raw": raw,
                "no_space": no_space,
                "designator": d,
                "position": "suffix",
                "core": _strip_spaces(core).lower(),
                "has_designator": True,
            }

    return {
        "raw": raw,
        "no_space": no_space,
        "designator": None,
        "position": None,
        "core": no_space.lower(),
        "has_designator": False,
    }


def _extract_pref_city(text: str) -> tuple[str, str]:
    """Extract (prefecture, municipality) from a Japanese address/location string.

    - prefecture: endswith 都/道/府/県
    - municipality: last match of 市/区/町/村 after the prefecture (more specific wins)
      e.g. '北海道 札幌市 手稲区' -> ('北海道', '手稲区')
    """
    if not text:
        return ("", "")
    s = re.sub(r"\s+", "", str(text))

    # Prefecture: first occurrence
    m_pref = re.search(r"(.{1,3}?[都道府県])", s)
    pref = m_pref.group(1) if m_pref else ""

    # Municipality candidates: 市/区/町/村 following the prefecture
    muni = ""
    if pref:
        after = s.split(pref, 1)[1]
    else:
        after = s

    # Capture sequences like '札幌市', '手稲区', '中城村', etc.
    munis = re.findall(r"([^0-9\W]{1,20}?[市区町村])", after)
    if munis:
        muni = munis[-1]  # choose the most specific (last)
    return (pref, muni)


def _location_consistent(input_location: str, extracted_address: str) -> bool:
    in_pref, in_city = _extract_pref_city(input_location)
    ex_pref, ex_city = _extract_pref_city(extracted_address)
    if in_pref and ex_pref and in_pref != ex_pref:
        return False
    # If user provided a city/ward, require it to match when we have it.
    if in_city:
        if not ex_city:
            # If extracted address doesn't include a city token, we can't be sure.
            return False
        if in_city != ex_city:
            return False
    return True

def _should_override_company_name(input_company: str, input_location: str, extracted_company: str, extracted_address: str) -> bool:
    """会社名を input.company で上書きしてよいケースか判定する.

    目的:
      - LLMが「株式会社」等を落とす/略記するケースを救済する（前株・後株どちらも）
      - ただし、前株↔後株の取り違え（例: '株式会社A' vs 'A株式会社'）は救済しない
        ※ その場合は上流で不一致として弾くべき

    具体例（OK）:
      - 株式会社サカイ引越センター ⇔ サカイ引越センター
      - サカイ引越センター株式会社 ⇔ サカイ引越センター
      - （株）サカイ引越センター ⇔ サカイ引越センター
      - サカイ引越センター(株) ⇔ サカイ引越センター

    具体例（NG）:
      - 株式会社サカイ引越センター ⇔ サカイ引越センター株式会社（前株↔後株）
    """
    in_a = _analyze_company_name(input_company)
    ex_a = _analyze_company_name(extracted_company)

    # 本体が一致しないなら不可
    if in_a["core"] != ex_a["core"]:
        return False

    # 所在地が整合しないなら不可
    if not _location_consistent(input_location, extracted_address):
        return False

    # 会社形態の扱い:
    # - input が法人種別を持ち、extracted が持たない（落ち/略記）のみ上書きを許可
    #   （前株・後株どちらの input でも許可する）
    if in_a["has_designator"] and not ex_a["has_designator"]:
        return True

    # extracted が法人種別を持つ場合は、ここでは上書きしない
    # （例: input が略称/屋号で extracted が正式名称の場合もある）
    return False

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
    api_start = time.time()
    
    try:
        llm = ChatGoogleGenerativeAI(
            model="gemini-2.5-flash",
            temperature=0,
            google_api_key=settings.GOOGLE_API_KEY,
            max_retries=0,
        )
        # ★追加：リトライ用の検索補助語（state.search_hintがあれば使う）
        hint = (getattr(state, "search_hint", None) or "").strip()
        
        company_q = state.company
        location_q = state.location
        
        # ★検索用は別変数にする（location_q / state.location はそのまま）
        search_location = location_q
        if hint:
            search_location = f"{location_q} {hint}".strip()
            logger.info("  🔎 リトライ用検索補助語を付与: %s", hint)
        
        logger.info("  🔎 検索入力: %s @ %s", company_q, search_location)
        
        resp = _invoke_with_retry(
            llm,
            prompt.format(company=company_q, location=search_location),
            tools=[GenAITool(google_search=GoogleSearch())],
        )

        api_elapsed = time.time() - api_start
        logger.info(f"  ✅ API呼び出し成功 ({api_elapsed:.2f}秒)")
        _wait_between_api_calls()  # API呼び出し間の間隔
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
    #content_urls = re.findall(url_pattern, resp.content)
    # resp.contentがリストの場合は文字列に変換
    content = resp.content if isinstance(resp.content, str) else str(resp.content)
    content_urls = re.findall(url_pattern, content)
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
        #direct_urls = [url for url in reference_urls if not url.startswith('https://vertexaisearch.cloud.google.com')]
        # リダイレクトURLから実際のURLを取得
        import requests
        direct_urls = []
        for url in reference_urls:
            if url.startswith('https://vertexaisearch.cloud.google.com'):
                try:
                    r = requests.head(url, allow_redirects=True, timeout=5)
                    if r.url and not r.url.startswith('https://vertexaisearch'):
                        direct_urls.append(r.url)
                except:
                    pass
            else:
                direct_urls.append(url)
        if direct_urls:
            logger.info(f"  ✅ Google検索から{len(direct_urls)}個の直接URL取得")
            urls.extend(direct_urls)
        else:
            logger.warning(f"  ⚠️ Google検索結果は全てリダイレクトURL（{len(reference_urls)}個）- スキップ")
            for url in reference_urls:
                logger.warning(f"    リダイレクトURL: {url}")
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
            model="gemini-2.5-flash",
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
    
    logger.info("  🕷️ Webページクロール中（depth=1, timeout=60秒）...")
    crawl_start = time.time()
    web_context = crawl_markdown(url, depth=1, timeout=60)
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
            model="gemini-2.5-flash",
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

    #state.company_info = resp.model_dump()
    # 住所が空の場合、入力のlocationをフォールバックとして使用
    if not resp.address or resp.address.strip() == "":
        logger.warning(f"  ⚠️ 住所が抽出できませんでした。入力のlocationを使用: {state.location}")
        resp.address = state.location.replace(" ", "")  # スペースを除去


    # 会社名の揺れ補正（安全側）
    # - LLMが「株式会社」等を省略したり、英字の大小のみが揺れるケースがあるため、
    #   住所（都道府県・可能なら市区町村）と会社名コアが一致する場合のみ input.company で補完する。
    if resp.company and state.company and resp.address:
        if _should_override_company_name(state.company, state.location, resp.company, resp.address):
            if resp.company != state.company:
                logger.warning(
                    f"  ⚠️ 会社名の表記揺れを補正します: extracted='{resp.company}' -> input='{state.company}'"
                )
            resp.company = state.company

    state.company_info = resp.model_dump()
    
    node_elapsed = time.time() - node_start
    logger.info(f"  ⏱️ ノード処理時間: {node_elapsed:.2f}秒")
    
    return state
