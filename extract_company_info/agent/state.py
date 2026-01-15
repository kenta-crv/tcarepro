"""LangGraph用の状態定義.

各ノード間で受け渡す共通の状態（State）を定義します。
"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field

from models.schemas import CompanyInfo


class ExtractState(BaseModel):
    """会社情報抽出フローの状態.

    Attributes:
        customer_id: 顧客ID（ログ用）。
        company: 会社名。
        location: 勤務地/所在地のテキスト（※この値自体は書き換えない）。
        required_businesses: 業種候補（配列）。
        required_genre: 事業内容候補（配列）。

        search_hint: リトライ時に検索クエリへ付与する補助語（location自体は変えない）。

        urls: 検索から得られたURL候補一覧。
        selected_url: 公式と推定したURL。
        html: 選定サイトのHTML本文。
        inquiry_text: 問い合わせURL抽出結果テキスト等。
        company_info: 抽出した会社情報。
    """

    # 入力/共通
    customer_id: Optional[str] = None
    company: str
    location: str
    required_businesses: list[str] = Field(default_factory=list)
    required_genre: list[str] = Field(default_factory=list)

    # ★追加：リトライ時の検索補助語（検索クエリにのみ加える）
    search_hint: Optional[str] = Field(
        default=None,
        description="リトライ時に検索クエリへ付与する補助語（state.location自体は変えない）",
    )

    # 中間/出力
    urls: list[str] = Field(default_factory=list)
    selected_url: Optional[str] = None
    html: Optional[str] = None
    inquiry_text: Optional[str] = None
    company_info: Optional[CompanyInfo] = None
