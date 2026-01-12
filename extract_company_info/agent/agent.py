import time
from langgraph.graph import StateGraph
from langgraph.graph.state import CompiledStateGraph

from agent import nodes
from agent.state import ExtractState
from models.schemas import CompanyInfo, ExtractRequest
from utils.validator import validate_address_format, validate_company_format
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
    """ExtractRequestを受け取り、グラフをコンパイル・実行してCompanyInfoを返す（最大1回リトライ）.

    - 会社名は「完全一致（==）」でチェックし、不一致なら再検索（1回）→ それでもダメならエラー
    - 所在地は「都道府県が一致しているか」をチェックし、不一致なら再検索（1回）→ それでもダメならエラー
      ※ location が都道府県を含まない場合は所在地チェックをスキップ

    Args:
        req: 会社名・勤務地・必須業種/必須ジャンルの配列を含む入力。

    Returns:
        CompanyInfo: 変換済みの会社情報モデル。

    Raises:
        Exception: 抽出に失敗した場合、または一致チェックに失敗した場合。
    """
    start_time = time.time()
    logger.info("=" * 80)
    logger.info(f"[START] 会社情報抽出を開始: {req.company} ({req.customer_id})")
    logger.info(f"  - 会社名: {req.company}")
    logger.info(f"  - 所在地: {req.location}")
    logger.info(f"  - 必須業種: {req.required_businesses}")
    logger.info(f"  - 必須ジャンル: {req.required_genre}")
    logger.info("=" * 80)

    # 都道府県抽出（location から最初に見つかったものを採用）
    # ※ utils/formtter.py を変更しない前提のため、ここでローカルに持ちます
    PREFECTURES = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]

    def _extract_pref(location: str | None) -> str | None:
        if not location:
            return None
        loc = str(location)
        for pref in PREFECTURES:
            if pref in loc:
                return pref
        return None

    expected_company = (req.company or "").strip()
    expected_pref = _extract_pref(req.location)

    last_error: Exception | None = None

    # 0: 初回 / 1: リトライ1回
    max_attempts = 2
    for attempt in range(max_attempts):
        attempt_label = "1/2" if attempt == 0 else "2/2"
        logger.info("[ATTEMPT %s] 処理を開始します", attempt_label)

        try:
            logger.info("[STEP 1/4] グラフのコンパイル中...")
            app = compile_graph()

            # ★重要：まず state を作る（これより前に init_state を触らない）
            init_state = ExtractState.model_validate(req.model_dump())

            # ★リトライ時だけ検索補助語を付与（init_state 作成後にやる）
            if attempt > 0:
                init_state.search_hint = build_retry_search_hint(init_state)
                logger.info("🔁 リトライ用 search_hint を設定: %s", init_state.search_hint)
            else:
                init_state.search_hint = None

            logger.info("  ✅ グラフコンパイル完了")

            logger.info("[STEP 2/4] グラフ実行中（get_urls → select_official → fetch_html）...")
            result = app.invoke(init_state)
            logger.info("  ✅ グラフ実行完了")

            logger.info("[STEP 3/4] CompanyInfo への変換中...")
            # resultはExtractStateオブジェクトまたは辞書の可能性がある
            if isinstance(result, dict):
                company_info_raw = result.get("company_info")
            else:
                company_info_raw = result.company_info if hasattr(result, "company_info") else None

            # CompanyInfoオブジェクトの場合は辞書に変換
            if isinstance(company_info_raw, CompanyInfo):
                company_info_payload = company_info_raw.model_dump()
            elif isinstance(company_info_raw, dict):
                company_info_payload = company_info_raw.copy()
            else:
                company_info_payload = {}

            # ★一致判定用：抽出直後（補完前）の会社名を退避
            extracted_company_before_fallback = (company_info_payload.get("company") or "").strip()

            # 会社名がバリデーション要件を満たさない場合は入力値から補完（※この挙動は維持）
            company_name = (company_info_payload.get("company") or "").strip()
            if not validate_company_format(company_name) and req.company:
                fallback_company = req.company.strip()
                if validate_company_format(fallback_company):
                    logger.warning(
                        "  ⚠️ 抽出した会社名がバリデーション要件を満たしていないため input.company で補完します: %s",
                        fallback_company,
                    )
                    company_info_payload["company"] = fallback_company

            # 住所がバリデーション要件（都/道/府/県を含む）を満たさない場合は location から補完（※この挙動は維持）
            address = (company_info_payload.get("address") or "").strip()
            if not validate_address_format(address):
                fallback_candidates = [
                    req.location.strip() if req.location else None,
                    f"{req.location.strip()} {address}".strip() if req.location and address else None,
                ]
                for candidate in fallback_candidates:
                    if candidate and validate_address_format(candidate):
                        logger.warning(
                            "  ⚠️ 抽出した住所がバリデーション要件を満たしていないため location で補完します: %s",
                            candidate,
                        )
                        company_info_payload["address"] = candidate
                        break

            company_info = CompanyInfo.model_validate(company_info_payload)
            logger.info("  ✅ CompanyInfo変換完了")

            # -----------------------------
            # ★追加：一致判定（再検索トリガ）
            # -----------------------------
            # 会社名：一致判定は「補完前の抽出会社名」で行う（補完で取り違えが隠れないように）
            if expected_company:
                if extracted_company_before_fallback:
                    if extracted_company_before_fallback != expected_company:
                        raise ValueError(
                            f"会社名が完全一致しません: input='{expected_company}' / extracted='{extracted_company_before_fallback}'"
                        )
                else:
                    # 抽出できていない場合は不一致扱い（= リトライへ）
                    raise ValueError(
                        f"会社名が抽出できません: input='{expected_company}' / extracted=''"
                    )

            # 所在地：都道府県が含まれる場合のみ一致チェック（都道府県が違えば別会社扱い）
            if expected_pref:
                extracted_address = company_info.address or ""
                if expected_pref not in extracted_address:
                    raise ValueError(
                        f"所在地（都道府県）が一致しません: input_pref='{expected_pref}' / extracted_address='{extracted_address}'"
                    )

            # -----------------------------
            # 成功ログ
            # -----------------------------
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
            last_error = e
            # 初回はリトライ、それでもダメならエラーで終了
            if attempt == 0:
                logger.warning("=" * 80)
                logger.warning(
                    "[RETRY] 抽出結果が不正/失敗のため再検索します（リトライ1回）: %s",
                    str(e)[:200],
                )
                logger.warning("=" * 80)
                continue

            elapsed = time.time() - start_time
            logger.error("=" * 80)
            logger.error(f"[ERROR] 抽出失敗: {req.company} ({req.customer_id})")
            logger.error(f"  - エラー: {type(e).__name__}: {str(e)[:200]}")
            logger.error(f"  - 処理時間: {elapsed:.2f}秒")
            logger.error("=" * 80)
            raise


    # 通常ここには到達しない想定だが保険
    if last_error:
        raise last_error
    raise ValueError("不明なエラー（last_error が None）")


def build_retry_search_hint(state: ExtractState) -> str:
    """リトライ時の検索補助語を組み立てる（locationは含めない）"""
    hints: list[str] = []

    # 法人格（会社名に含まれていれば付与）
    if "株式会社" in state.company:
        hints.append("株式会社")
    elif "有限会社" in state.company:
        hints.append("有限会社")
    elif "合同会社" in state.company:
        hints.append("合同会社")

    # 公式サイトに寄せる鉄板語
    hints.extend([
        "公式",
        "会社概要",
        "企業情報",
        "お問い合わせ",
        "法人番号",
    ])

    return " ".join(hints)

