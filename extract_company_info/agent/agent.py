from langgraph.graph import StateGraph
from langgraph.graph.state import CompiledStateGraph

from agent import nodes
from agent.state import ExtractState
from models.schemas import CompanyInfo, ExtractRequest


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
    graph.add_node("fetch_html", nodes.node_fetch_html)

    graph.set_entry_point("get_urls")
    graph.add_edge("get_urls", "fetch_html")
    graph.set_finish_point("fetch_html")

    return graph.compile()


def extract_company_info(req: ExtractRequest) -> CompanyInfo:
    """ExtractRequestを受け取り、グラフをコンパイル・実行してCompanyInfoを返す.

    Args:
        req: 会社名・勤務地・必須業種/必須ジャンルの配列を含む入力。

    Returns:
        CompanyInfo: 変換済みの会社情報モデル。

    """
    app = compile_graph()
    init_state = ExtractState.model_validate(req.model_dump())

    result = app.invoke(init_state)

    return CompanyInfo.model_validate(result.get("company_info"))
