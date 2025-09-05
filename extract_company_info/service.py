"""サービス層: 会社情報抽出のオーケストレーション.

`ExtractRequest` を受け取り、LLMとスクレイピングを組み合わせて
`CompanyInfo` を生成します。
"""

from llm import (
    extract_contact_url_from_site,
    generate_overview_with_search,
    infer_industry_from_site,
    select_official_website,
    summarize_business_from_site,
)
from net import normalize_url
from parse import extract_value_by_label
from schemas import CompanyInfo, ExtractRequest


def extract_company_profile(req: ExtractRequest) -> CompanyInfo:
    """会社情報を抽出し、構造化して返す.

    Args:
        req (ExtractRequest): 抽出に必要な入力（会社名、勤務地、業種候補、事業内容候補）。

    Returns:
        CompanyInfo: 抽出・整形済みの会社情報データモデル。

    """
    # 1) 会社情報本文の抽出（会社名/電話番号/住所/代表者）
    text, refs = generate_overview_with_search(req.company, req.location)

    # 2) 参考URL群から公式サイトURLを推定
    url_text = select_official_website(refs)
    url = normalize_url(url_text) or (url_text or "").strip()

    # 3) 公式サイトから問い合わせURL/業種/事業内容を推定
    inquiry_text = extract_contact_url_from_site(url)
    industry_text = infer_industry_from_site(url, req.industry)
    genre_text = summarize_business_from_site(url, req.genre)

    # 本文から各項目を抽出
    company_out = extract_value_by_label(text, "会社名")
    tel_out = extract_value_by_label(text, "電話番号")
    address_out = extract_value_by_label(text, "住所")
    first_name_out = extract_value_by_label(text, "代表者")

    inquiry_out = extract_value_by_label(inquiry_text, "問い合わせURL")
    if inquiry_out == "不明":
        # ラベルのゆれ「お問い合わせURL」にも対応
        inquiry_out = extract_value_by_label(inquiry_text, "お問い合わせURL")

    business_out = extract_value_by_label(industry_text, "業種")
    genre_out = extract_value_by_label(genre_text, "事業内容")

    return CompanyInfo.model_validate(
        {
            "company": company_out or "不明",
            "tel": tel_out or "不明",
            "address": address_out or "不明",
            "first_name": first_name_out or "不明",
            "url": url or "不明",
            "contact_url": inquiry_out or "不明",
            "business": business_out or "不明",
            "genre": genre_out or "不明",
        },
    )
