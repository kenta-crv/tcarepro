"""プロンプト生成ユーティリティ.

求人情報から会社概要抽出のためのプロンプトを生成します。
"""

PROMPT_TMPL = """
下記は求人情報です。
これをもとに、募集元の会社の本社情報をweb検索で探し、以下の会社概要を抽出してください。
不明な場合は不明と記載してください。
# 求人情報

会社名:{company}
勤務地:{location}

# 会社概要
- 会社名（無駄な半角はいれない。例：「医療法人 ABC」ではなく、「医療法人ABC」）
- 電話番号(本社のもの 半角数字と-のみで記載)
- 住所(本社のもの 郵便番号は含めない 必ず都道府県から始める)
- 代表者(名前のみ 肩書は含めない)
# 出力形式
- 会社名: ここに出力
- 電話番号: ここに出力
- 住所: ここに出力
- 代表者: ここに出力
"""


def build_company_prompt(company: str, location: str) -> str:
    """会社概要抽出用のプロンプトを生成する.

    Args:
        company (str): 会社名（求人に記載の名称）。
        location (str): 勤務地情報（都道府県・市区など）。

    Returns:
        str: Gemini へ与えるプロンプト文字列。

    """
    return PROMPT_TMPL.format(company=company, location=location)
