import time
from langgraph.graph import StateGraph
from langgraph.graph.state import CompiledStateGraph

from agent import nodes
from agent.state import ExtractState
from models.schemas import CompanyInfo, ExtractRequest
from utils.logger import get_logger

logger = get_logger()


def compile_graph() -> CompiledStateGraph:
    """会社情報抽出の LangGraph をコンパイルして返す.

    グラフは以下の順でノードを実行する。
    - get_urls → select_official → fetch_html → extract_contact → infer_industry
      → summarize_business → finalize

    Returns:
        CompiledStateGraph: コンパイル済みグラフ。

    """
    graph = StateGraph(ExtractState)
    graph.add_node("get_urls", nodes.node_get_url_candidates)
    graph.add_node("select_official", nodes.node_select_official_website)
    graph.add_node("fetch_html", nodes.node_fetch_html)

    graph.set_entry_point("get_urls")
    graph.add_edge("get_urls", "select_official")
    graph.add_edge("select_official", "fetch_html")
    graph.set_finish_point("fetch_html")

    return graph.compile()


def extract_company_info(req: ExtractRequest) -> CompanyInfo:
    """ExtractRequestを受け取り、グラフをコンパイル・実行してCompanyInfoを返す.

    Args:
        req: 会社名・勤務地・必須業種/必須ジャンルの配列を含む入力。

    Returns:
        CompanyInfo: 変換済みの会社情報モデル。

    """
    start_time = time.time()
    logger.info("=" * 80)
    logger.info(f"[START] 会社情報抽出を開始: {req.company} ({req.customer_id})")
    logger.info(f"  - 会社名: {req.company}")
    logger.info(f"  - 所在地: {req.location}")
    logger.info(f"  - 必須業種: {req.required_businesses}")
    logger.info(f"  - 必須ジャンル: {req.required_genre}")
    logger.info("=" * 80)
    
    try:
        logger.info("[STEP 1/4] グラフのコンパイル中...")
        app = compile_graph()
        init_state = ExtractState.model_validate(req.model_dump())
        logger.info("  ✅ グラフコンパイル完了")
        
        logger.info("[STEP 2/4] グラフ実行中（get_urls → select_official → fetch_html）...")
        result = app.invoke(init_state)
        logger.info("  ✅ グラフ実行完了")
        
        logger.info("[STEP 3/4] CompanyInfo への変換中...")
        company_info = CompanyInfo.model_validate(result.get("company_info"))
        logger.info("  ✅ CompanyInfo変換完了")
        
        elapsed = time.time() - start_time
        logger.info("[STEP 4/4] 抽出結果:")
        logger.info(f"  - 会社名: {company_info.company}")
        logger.info(f"  - 電話番号: {company_info.tel}")
        logger.info(f"  - 住所: {company_info.address}")
        logger.info(f"  - URL: {company_info.url}")
        logger.info(f"  - お問い合わせURL: {company_info.contact_url}")
        logger.info(f"  - 処理時間: {elapsed:.2f}秒")
        logger.info("=" * 80)
        logger.info(f"[SUCCESS] 抽出完了: {req.company} ({req.customer_id})")
        logger.info("=" * 80)
        
        return company_info
        
    except Exception as e:
        elapsed = time.time() - start_time
        logger.error("=" * 80)
        logger.error(f"[ERROR] 抽出失敗: {req.company} ({req.customer_id})")
        logger.error(f"  - エラー: {type(e).__name__}: {str(e)[:200]}")
        logger.error(f"  - 処理時間: {elapsed:.2f}秒")
        logger.error("=" * 80)
        raise
