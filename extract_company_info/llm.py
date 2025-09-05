"""LLM呼び出しユーティリティ.

Gemini API を用いたコンテンツ生成と検索連携を提供します。
"""

import time

from google import genai
from google.genai import types

from net import fetch_html
from prompts import build_company_prompt
from settings import settings

# 設定は pydantic-settings から読み込む


def generate_overview_with_search(company: str, location: str) -> tuple[str, list[str]]:
    """Google Search を有効化して会社概要を生成する.

    Args:
        company (str): 会社名。
        location (str): 勤務地。

    Returns:
        Tuple[str, List[str]]: 生成テキストと参考URL（タイトルとURL）のリスト。

    """
    client = genai.Client(api_key=settings.GOOGLE_API_KEY)

    # Google検索ツールを有効化（グラウンディング）
    search_tool = types.Tool(google_search=types.GoogleSearch())
    config = types.GenerateContentConfig(tools=[search_tool])

    resp = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=build_company_prompt(company, location),
        config=config,
    )

    text = resp.text or ""

    # 参考URL（グラウンディングの出典）を抽出
    refs: list[str] = []
    cand = resp.candidates[0] if resp.candidates else None
    gm = getattr(cand, "grounding_metadata", None)
    if gm and getattr(gm, "grounding_chunks", None):
        for ch in gm.grounding_chunks:
            web = getattr(ch, "web", None)
            if web and web.uri:
                title = getattr(web, "title", "") or web.uri
                refs.append(f"{title} - {web.uri}")

    return text, refs


def select_official_website(refs: list[str]) -> str:
    """参考URL候補から公式サイトURLを1つ選ぶ.

    Args:
        refs (list[str]): 参考URL候補（タイトルとURLを含む想定）。

    Returns:
        str: モデルが選択した公式サイトURL（文字列）。

    """
    urls: list[str] = []
    for line in refs:
        left = line.split(" - ", 1)[0]  # ハイフン左側
        urls.append(left)

    time.sleep(15)  # 呼び出し間隔の調整
    prompt = f"""
    次のリストから、本社の公式webサイトだと思われるURLを一つ抜き出してください。
    出力はURLのみを出力し、余計なものは出力しないでください。
    必ずリストの中から選択してください。
    # リスト
    {urls}
    # 出力
    URL
    """
    client = genai.Client(api_key=settings.GOOGLE_API_KEY)
    config = types.GenerateContentConfig()
    resp = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt,
        config=config,
    )
    return resp.text


def infer_industry_from_site(url: str, industry: str) -> str:
    """公式サイトのHTMLから最適な業種を1つ選択する.

    Args:
        url (str): 公式サイトのURL。
        industry (str): 業種候補（カンマ区切り）。

    Returns:
        str: "- 業種: ..." の形式の文字列。

    """
    try:
        content = fetch_html(url)
    except Exception:  # noqa: BLE001
        return f"""
- 業種: {industry.split(",")[0]}
"""

    prompt = f"""
    次の選択肢はカンマ区切りは業種の選択肢です。
    選択肢の中からHTMLコンテンツに最も近い業種を一つだけ選択してください

    # コンテンツ
    {content}
    # 選択肢
    {industry}
    # 情報
    - 業種
    # 出力形式
    - 業種: ここに出力
    """
    client = genai.Client(api_key=settings.GOOGLE_API_KEY)
    config = types.GenerateContentConfig()
    resp = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt,
        config=config,
    )
    return resp.text


def extract_contact_url_from_site(url: str) -> str:
    """公式サイトから問い合わせURLを抽出する.

    Args:
        url (str): 公式サイトのURL。

    Returns:
        str: "- 問い合わせURL: ..." の形式の文字列。失敗時は不明。

    """
    time.sleep(15)
    try:
        content = fetch_html(url)
    except Exception:  # noqa: BLE001
        return """
- 問い合わせURL: 不明
"""

    prompt = f"""
    次のHTMLコンテンツを元に、
    下記の情報を抽出して出力してください。
    不明な場合は不明と記載してください。

    # コンテンツ
    {content}
    # 情報
    - 問い合わせURL(ドメインも含めた完全URL)
    # 出力形式
    - 問い合わせURL: ここに出力
    """
    client = genai.Client(api_key=settings.GOOGLE_API_KEY)
    config = types.GenerateContentConfig()
    resp = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt,
        config=config,
    )
    return resp.text


def summarize_business_from_site(url: str, genre: str) -> str:
    """公式サイトの内容から事業内容（ジャンル）を要約する.

    Args:
        url (str): 公式サイトのURL。
        genre (str): 事業内容の選択肢（カンマ区切り）。

    Returns:
        str: "- 事業内容: ..." の形式の文字列。

    """
    time.sleep(15)
    try:
        content = fetch_html(url)
    except Exception:  # noqa: BLE001
        return f"""
- 事業内容: {genre}
"""

    prompt = f"""
    次のHTMLコンテンツを元に、事業内容を50文字以内で端的に記載してください。
    基本的に選択肢に記載されているカンマで区切られているいずれかの文字列を含めるようにしてください。
    ただし、HTMLコンテンツをみて事業内容が選択肢のどれとも**まったく関連しない**と判断できた場合は
    事業内容は不明と出力してください。

    # コンテンツ
    {content}
    # 選択肢
    {genre}
    # 情報
    - 事業内容（URLを参考に事業内容を50文字以内で端的に記載）
    # 出力形式
    - 事業内容: ここに出力
    """
    client = genai.Client(api_key=settings.GOOGLE_API_KEY)
    config = types.GenerateContentConfig()
    resp = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt,
        config=config,
    )
    return resp.text
