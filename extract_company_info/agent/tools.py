"""マルチツール用の関数定義とハンドラー.

Google Generative APIのFunctionDeclaration形式で関数ツールを定義し、
LLMからの呼び出しを処理するハンドラーを提供します。
"""

import json
from typing import Any, Dict, Optional
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup
from google.genai import types as genai_types

from utils.crawl4ai_util import crawl_markdown
from utils.logger import get_logger
from utils.net import _check_single_url
from utils.validator import (
    validate_address_format,
    validate_company_format,
    validate_tel_format,
    valid_business,
    valid_genre,
)

logger = get_logger()


def _dict_to_schema(schema_dict: Dict[str, Any]) -> genai_types.Schema:
    """辞書形式のJSON Schemaをgenai Schemaに変換."""
    return genai_types.Schema.model_validate(schema_dict)


def get_check_url_accessibility_declaration() -> genai_types.FunctionDeclaration:
    """URL到達可能性チェック関数のFunctionDeclarationを返す."""
    schema_dict = {
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "チェックするURL（例: https://example.com）",
            },
        },
        "required": ["url"],
    }
    return genai_types.FunctionDeclaration(
        name="check_url_accessibility",
        description=(
            "指定されたURLがアクセス可能かどうかを確認します。"
            "URLに到達できる場合は最終URL（リダイレクト後のURL）を返し、"
            "到達できない場合はNoneを返します。"
        ),
        parameters=_dict_to_schema(schema_dict),
    )


def get_crawl_website_declaration() -> genai_types.FunctionDeclaration:
    """ウェブサイトクロール関数のFunctionDeclarationを返す."""
    schema_dict = {
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "クロールするウェブサイトのURL",
            },
            "timeout": {
                "type": "integer",
                "description": "タイムアウト秒数（デフォルト: 10秒）",
                "default": 10,
            },
        },
        "required": ["url"],
    }
    return genai_types.FunctionDeclaration(
        name="crawl_website",
        description=(
            "指定されたURLのウェブサイトをクロールし、Markdown形式のコンテンツを取得します。"
            "クロールに失敗した場合は空文字列を返します。"
        ),
        parameters=_dict_to_schema(schema_dict),
    )


def get_crawl_footer_links_declaration() -> genai_types.FunctionDeclaration:
    """フッターと関連リンクをクロールするFunctionDeclarationを返す."""
    schema_dict = {
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "フッターを解析するベースURL",
            },
            "max_links": {
                "type": "integer",
                "description": "クロールするフッターリンクの最大数（1-10）",
                "default": 5,
            },
            "timeout": {
                "type": "integer",
                "description": "ベースURL取得時のタイムアウト秒数",
                "default": 10,
            },
            "link_timeout": {
                "type": "integer",
                "description": "フッターリンククロール時のタイムアウト秒数",
                "default": 10,
            },
        },
        "required": ["url"],
    }
    return genai_types.FunctionDeclaration(
        name="crawl_footer_links",
        description=(
            "ページのフッターを取得し、重要そうなリンクをクロールしてMarkdownを返します。"
            "問い合わせ・会社概要などフッターにしかない情報の収集に利用してください。"
        ),
        parameters=_dict_to_schema(schema_dict),
    )


def get_validate_company_info_declaration() -> genai_types.FunctionDeclaration:
    """会社情報バリデーション関数のFunctionDeclarationを返す."""
    schema_dict = {
        "type": "object",
        "properties": {
            "company": {
                "type": "string",
                "description": "会社名（「株式会社」「有限会社」などを含む必要がある）",
            },
            "tel": {
                "type": "string",
                "description": "電話番号（半角数字とハイフンのみ、ハイフンを含む必要がある）",
            },
            "address": {
                "type": "string",
                "description": "住所（「都」「道」「府」「県」のいずれかを含む必要がある）",
            },
        },
        "required": [],
    }
    return genai_types.FunctionDeclaration(
        name="validate_company_info",
        description=(
            "抽出した会社情報の各フィールドを検証します。"
            "検証結果と、エラーがある場合は修正案を返します。"
        ),
        parameters=_dict_to_schema(schema_dict),
    )


def get_report_url_scores_declaration() -> genai_types.FunctionDeclaration:
    """URLスコアを構造化して返すためのFunctionDeclaration."""
    schema_dict = {
        "type": "object",
        "properties": {
            "urls": {
                "type": "array",
                "description": "URLスコアのリスト",
                "items": {
                    "type": "object",
                    "properties": {
                        "url": {"type": "string", "description": "URL"},
                        "score": {
                            "type": "number",
                            "description": "関連度スコア（0.0-1.0）",
                        },
                    },
                    "required": ["url", "score"],
                },
            }
        },
        "required": ["urls"],
    }
    return genai_types.FunctionDeclaration(
        name="report_url_scores",
        description="URL候補と各スコアを構造化して返します。",
        parameters=_dict_to_schema(schema_dict),
    )


def get_report_company_info_declaration() -> genai_types.FunctionDeclaration:
    """会社情報を構造化して返すためのFunctionDeclaration."""
    schema_dict = {
        "type": "object",
        "properties": {
            "company": {"type": "string", "description": "会社名"},
            "tel": {"type": "string", "description": "電話番号"},
            "address": {"type": "string", "description": "住所"},
            "first_name": {"type": "string", "description": "代表者・担当者名"},
            "url": {"type": "string", "description": "公式URL"},
            "contact_url": {"type": "string", "description": "問い合わせURL"},
        },
        "required": ["company", "tel", "address", "url"],
    }
    return genai_types.FunctionDeclaration(
        name="report_company_info",
        description="抽出した会社情報を構造化して返します。",
        parameters=_dict_to_schema(schema_dict),
    )


def handle_check_url_accessibility(args: Dict[str, Any]) -> Dict[str, Any]:
    """check_url_accessibility関数の呼び出しを処理."""
    url = args.get("url", "")
    if not url:
        return {"accessible": False, "final_url": None, "error": "URLが指定されていません"}

    try:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
        timeout = 10
        result = _check_single_url(url, timeout, headers)
        if result:
            logger.debug(f"  ✅ check_url_accessibility: {url} -> {result}")
            return {"accessible": True, "final_url": result}
        else:
            logger.debug(f"  ❌ check_url_accessibility: {url} - 到達不可")
            return {"accessible": False, "final_url": None, "error": "URLに到達できませんでした"}
    except Exception as e:
        logger.error(f"  ❌ check_url_accessibility エラー: {type(e).__name__}: {str(e)[:200]}")
        return {"accessible": False, "final_url": None, "error": f"エラー: {str(e)[:200]}"}


def handle_crawl_website(args: Dict[str, Any]) -> Dict[str, Any]:
    """crawl_website関数の呼び出しを処理."""
    url = args.get("url", "")
    timeout = args.get("timeout", 10)

    if not url:
        return {"success": False, "content": "", "error": "URLが指定されていません"}

    try:
        logger.debug(f"  🕷️ crawl_website: {url} (timeout={timeout}秒)")
        content = crawl_markdown(url, depth=0, timeout=timeout)
        if content:
            logger.debug(f"  ✅ crawl_website: {len(content)}文字取得成功")
            # コンテンツが長すぎる場合は先頭部分のみ返す
            max_length = 50000  # 50,000文字に制限
            if len(content) > max_length:
                content = content[:max_length] + "\n\n[... コンテンツが長いため途中で切られています ...]"
            return {"success": True, "content": content, "length": len(content)}
        else:
            logger.warning(f"  ⚠️ crawl_website: {url} - クロール失敗またはタイムアウト")
            return {"success": False, "content": "", "error": "クロールに失敗しました"}
    except Exception as e:
        logger.error(f"  ❌ crawl_website エラー: {type(e).__name__}: {str(e)[:200]}")
        return {"success": False, "content": "", "error": f"エラー: {str(e)[:200]}"}


def handle_crawl_footer_links(args: Dict[str, Any]) -> Dict[str, Any]:
    """フッターとそのリンク先をクロールして返す."""
    url = (args.get("url") or "").strip()
    if not url:
        return {"success": False, "footer_text": "", "links": [], "error": "URLが指定されていません"}

    max_links = int(args.get("max_links", 5) or 5)
    max_links = max(1, min(max_links, 10))
    timeout = int(args.get("timeout", 10) or 10)
    link_timeout = int(args.get("link_timeout", 10) or 10)

    headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
    try:
        resp = requests.get(url, headers=headers, timeout=timeout, allow_redirects=True, verify=False)
        resp.raise_for_status()
    except requests.RequestException as e:  # noqa: PERF203
        logger.error(f"  ❌ crawl_footer_links: ベースURL取得失敗: {type(e).__name__}: {str(e)[:200]}")
        return {
            "success": False,
            "footer_text": "",
            "links": [],
            "error": f"ベースURLの取得に失敗しました: {str(e)[:200]}",
        }

    soup = BeautifulSoup(resp.text, "html.parser")
    footer = soup.find("footer")
    footer_text = footer.get_text(separator="\n", strip=True) if footer else ""

    if not footer:
        logger.warning("  ⚠️ crawl_footer_links: <footer>要素が見つかりません")

    base_url = resp.url or url
    anchors = footer.find_all("a", href=True) if footer else []

    links = []
    seen = set()
    for anchor in anchors:
        if len(links) >= max_links:
            break
        href = anchor.get("href", "").strip()
        if not href:
            continue
        absolute_url = urljoin(base_url, href)
        parsed = urlparse(absolute_url)
        if parsed.scheme not in {"http", "https"}:
            continue
        if absolute_url.lower().startswith(("mailto:", "tel:")):
            continue
        if absolute_url in seen:
            continue
        seen.add(absolute_url)

        anchor_text = anchor.get_text(" ", strip=True)
        try:
            markdown = crawl_markdown(absolute_url, timeout=link_timeout)
        except Exception as e:  # noqa: BLE001
            logger.warning(f"  ⚠️ crawl_footer_links: 子リンクのクロールに失敗: {absolute_url} ({type(e).__name__})")
            markdown = ""

        max_length = 8000
        if len(markdown) > max_length:
            markdown = markdown[:max_length] + "\n\n[... trimmed ...]"

        links.append(
            {
                "url": absolute_url,
                "anchor_text": anchor_text,
                "content": markdown,
                "length": len(markdown),
            }
        )

    return {
        "success": True,
        "footer_text": footer_text,
        "links": links,
        "link_count": len(links),
    }


def handle_validate_company_info(args: Dict[str, Any]) -> Dict[str, Any]:
    """validate_company_info関数の呼び出しを処理."""
    result = {
        "valid": True,
        "errors": [],
        "suggestions": {},
    }

    company = args.get("company", "").strip() if args.get("company") else ""
    tel = args.get("tel", "").strip() if args.get("tel") else ""
    address = args.get("address", "").strip() if args.get("address") else ""
    # business = args.get("business", "").strip() if args.get("business") else ""
    # genre = args.get("genre", "").strip() if args.get("genre") else ""
    # required_businesses = args.get("required_businesses", [])
    # required_genre = args.get("required_genre", [])

    # 会社名の検証
    if company:
        if not validate_company_format(company):
            result["valid"] = False
            result["errors"].append(
                "会社名の形式が不正です。「株式会社」「有限会社」「合同会社」などを含み、"
                "支店・営業所・括弧・スペースを含まず、全角英数字/記号を含まない必要があります。"
            )
    else:
        result["errors"].append("会社名が指定されていません")

    # 電話番号の検証
    if tel:
        if not validate_tel_format(tel):
            result["valid"] = False
            result["errors"].append(
                "電話番号の形式が不正です。半角数字とハイフンのみ、ハイフンを含む必要があります。"
            )
    else:
        result["errors"].append("電話番号が指定されていません")

    # 住所の検証
    if address:
        if not validate_address_format(address):
            result["valid"] = False
            result["errors"].append(
                "住所の形式が不正です。「都」「道」「府」「県」のいずれかを含む必要があります。"
            )
    else:
        result["errors"].append("住所が指定されていません")

    # 業種・ジャンルの検証は削除（入力データから自動設定されるため）

    return result


def handle_function_call(function_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
    """関数呼び出しを処理して結果辞書を返す."""
    if function_name == "check_url_accessibility":
        result = handle_check_url_accessibility(args)
    elif function_name == "crawl_website":
        result = handle_crawl_website(args)
    elif function_name == "crawl_footer_links":
        result = handle_crawl_footer_links(args)
    elif function_name == "validate_company_info":
        result = handle_validate_company_info(args)
    else:
        result = {"error": f"未知の関数: {function_name}"}

    return result


def get_function_declarations() -> list[genai_types.FunctionDeclaration]:
    """全ての関数宣言を返す."""
    return [
        get_check_url_accessibility_declaration(),
        get_crawl_website_declaration(),
        get_crawl_footer_links_declaration(),
        get_validate_company_info_declaration(),
    ]

