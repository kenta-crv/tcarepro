from google import genai
from google.genai import types
from dotenv import load_dotenv
import os
import re
from urllib.parse import urlparse
import time
import requests
from typing import Optional

load_dotenv()

PROMPT_TMPL = """
下記は求人情報です。
これをもとに、募集元の会社の本社情報をweb検索で探し、以下の会社概要を抽出してください。
不明な場合は不明と記載してください。
# 求人情報

会社名:{company}
勤務地:{location}

# 会社概要
- 会社名
- 電話番号(本社のもの)
- 住所(本社のもの 郵便番号は含めない)
- 代表者(名前のみ 肩書は含めない)
# 出力形式
- 会社名: ここに出力
- 電話番号: ここに出力
- 住所: ここに出力
- 代表者: ここに出力
"""

def build_prompt(company: str, location: str) -> str:
    return PROMPT_TMPL.format(company=company, location=location)

def extract_company_info(company: str, location: str) -> tuple[str, list[str]]:
    """
    Gemini 2.5 Flash + Google Search で本社情報を抽出。
    返り値: (本文テキスト, 参考URLリスト)
    """
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))

    # Google検索ツールを有効化（グラウンディング）
    # docs: https://ai.google.dev/gemini-api/docs/google-search
    search_tool = types.Tool(google_search=types.GoogleSearch())

    config = types.GenerateContentConfig(
        tools=[search_tool]
    )

    resp = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=build_prompt(company, location),
        config=config,
    )

    text = resp.text or ""

    # 参考URL（グラウンディングの出典）を取り出しておく（任意）
    refs = []
    cand = resp.candidates[0] if resp.candidates else None
    gm = getattr(cand, "grounding_metadata", None)
    if gm and getattr(gm, "grounding_chunks", None):
        for ch in gm.grounding_chunks:
            web = getattr(ch, "web", None)
            if web and web.uri:
                title = getattr(web, "title", "") or web.uri
                refs.append(f"{title} - {web.uri}")

    return text, refs

def normalize_to_url(text: str) -> Optional[str]:
    """
    左側の文字列から正しいURLを作る:
    - 既に http(s):// ならそのまま
    - それ以外は https:// を付与
    - URLとして不正なら None
    """
    s = text.strip().strip(" '\"")  # 余計な空白や引用符を除去
    if not s:
        return None
    if re.match(r"^https?://", s, re.IGNORECASE):
        url = s
    else:
        url = f"https://{s}"

    parsed = urlparse(url)
    return url if parsed.scheme and parsed.netloc else None

def fetch_html(url: str, timeout: int = 15) -> str:
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }
    r = requests.get(url, headers=headers, timeout=timeout)
    r.raise_for_status()  # 4xx/5xx を例外に
    # 文字コード推定（charset-normalizerによる自動判別）
    r.encoding = r.apparent_encoding or r.encoding
    return r.text


def get_url(refs):
    urls = []
    for line in refs:
        left = line.split(" - ", 1)[0]  # ハイフンの左側だけ
        url = normalize_to_url(left)
        urls.append(url)
    time.sleep(15)
    prompt = f"""
    次のリストから、本社の公式webサイトだと思われるURLを一つ抜き出してください。
    出力はURLのみを出力し、余計なものは出力しないでください。
    必ずリストの中から選択してください。
    # リスト
    {urls}
    # 出力
    URL
    """
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))

    config = types.GenerateContentConfig()

    resp = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt,
        config=config,
    )

    return resp.text

def get_industry(url, industry):
    try:
        content = fetch_html(url)
    except:
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
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))

    config = types.GenerateContentConfig()

    resp = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt,
        config=config,
    )

    return resp.text

def get_info_from_url(url):
    time.sleep(15)
    try:
        content = fetch_html(url)
    except:
        return """
        - 問い合わせURL: 不明
        - 事業内容: 不明
        """
    prompt = f"""
    次のHTMLコンテンツを元に、
    下記の情報を抽出して出力してください。
    不明な場合は不明と記載してください。
    
    # コンテンツ
    {content}
    # 情報
    - 問い合わせURL(ドメインも含めた完全URL)
    - 事業内容（URLを参考に事業内容を50文字以内で端的に記載）  
    # 出力形式
    - 問い合わせURL: ここに出力
    - 事業内容: ここに出力
    """
    client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))

    config = types.GenerateContentConfig()

    resp = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt,
        config=config,
    )

    return resp.text

if __name__ == "__main__":
    text, refs = extract_company_info("UTエイム株式会社", "北海道 苫小牧市")
    print(text)
    print(refs)
    url = get_url(refs)
    print(url)
    info = get_info_from_url(url)
    print(info)
