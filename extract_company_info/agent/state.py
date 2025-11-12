"""LangGraph用の状態定義.

各ノード間で受け渡す共通の状態（State）を定義します。
"""

from typing import Optional

from pydantic import BaseModel

from models.schemas import CompanyInfo


class ExtractState(BaseModel):
    """会社情報抽出フローの状態.

    Attributes:
        customer_id: 顧客ID（ログ用）。
        company: 会社名。
        location: 勤務地/所在地のテキスト。
        required_businesses: 業種候補（カンマ区切り文字列）。
        required_genre: 事業内容候補（カンマ区切り文字列）。
        urls: 検索から得られたURL候補一覧。
        selected_url: 公式と推定したURL。
        html: 選定サイトのHTML本文。
        inquiry_text: 問い合わせURLの抽出結果テキスト（「- 問い合わせURL: ...」形式）。
        industry_text: 業種の推定結果テキスト（「- 業種: ...」形式）。
        genre_text: 事業内容の要約テキスト（「- 事業内容: ...」形式）。

    """

    # 入力
    customer_id: str
    company: str
    location: str
    required_businesses: list[str]
    required_genre: list[str]
    # 中間/出力
    urls: Optional[list[str]] = None
    company_info: Optional[CompanyInfo] = None
