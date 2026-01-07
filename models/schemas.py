"""Pydanticスキーマ定義.

【修正履歴】
- 2026/01/03: address に normalize_address を適用する field_validator を追加
- 2026/01/03: first_name を Optional[str] = None に変更（Geminiが返さない場合の対応）
"""

from typing import Optional

from pydantic import BaseModel, Field, field_validator

from utils.formtter import normalize_company_name, normalize_tel_number, normalize_address
from utils.validator import (
    validate_address_format,
    validate_company_format,
    validate_tel_format,
)


class ExtractRequest(BaseModel):
    """入力."""

    customer_id: str
    company: str
    location: str
    required_businesses: list[str]
    required_genre: list[str]


class CompanyInfo(BaseModel):
    """抽出した会社情報."""

    company: str = Field(
        description=(
            "会社名。以下を満たす必要があります: \n"
            "- 『株式会社/有限会社/社会福祉/合同会社/医療法人/行政書士/一般社団法人/合資会社/法律事務所』のいずれかを含む\n"
            "- 支店・営業所・括弧（半角/全角）・スペース（半角/全角）を含まない\n"
            "- 全角英数字・記号（Ａ-Ｚａ-ｚ０-９・！-～）を含まない"
        ),
    )
    tel: str = Field(
        description=(
            "電話番号。半角数字とハイフンのみで、ハイフンを含む必要があります。"
            "数字のみや括弧( ) を含む形式は不可。"
        ),
    )
    ##########
    # 「必須（絶対ないといけない）」から「なくてもOK（Optional）」に変える 2026/01/04(Sun) T.Abe
    ##########
    address: Optional[str] = Field(
        default=None, 
        description="住所。『都/道/府/県』のいずれかを含む必要があります。"
    )
    first_name: Optional[str] = Field(
        default=None,  # ★追加: Geminiが返さない場合のデフォルト値
        description="担当者名/代表者名。肩書は含めず、苗字と名前の間には空欄をいれない",
    )
    url: str = Field(description="公式サイトのURL")
    contact_url: Optional[str] = Field(
        default=None,  # ★追加: 明示的にデフォルト値を設定
        description="問い合わせページのURL。",
    )
    business: str = Field(
        description="抽出された業種。指定がある場合は特定文字列を含む必要がある。詳細は別途記載。",
    )
    genre: str = Field(
        description="抽出された事業内容。50文字程度で簡潔に記載。指定がある場合は特定文字列を含む必要がある。詳細は別途記載。",
    )

    # 会社名の形式チェック
    @field_validator("company", mode="before")
    @classmethod
    def _format_company(cls, v: str) -> str:
        return normalize_company_name(v)

    @field_validator("company", mode="after")
    @classmethod
    def _validate_company(cls, v: str) -> str:
        """会社名をフォーマットルールに基づき検証する.

        ルールは utils/validator.validate_company_format に準拠。

        Args:
            v: 入力の会社名。

        Returns:
            str: 検証済みの会社名。

        Raises:
            ValueError: 形式に合致しない場合。

        """
        # バリデーションに失敗したら例外
        if not validate_company_format(v):
            msg = (
                "会社名の形式が不正です。『株式会社/有限会社/社会福祉/合同会社/医療法人/行政書士/一般社団法人/合資会社/法律事務所』の"
                "いずれかを含み、支店・営業所・括弧・スペースを含まず、全角英数字/記号を含まない必要があります。"
            )
            raise ValueError(
                msg,
            )
        return v

    # 電話番号の形式チェック
    @field_validator("tel", mode="before")
    @classmethod
    def _format_tel(cls, v: str) -> str:
        return normalize_tel_number(v)

    @field_validator("tel", mode="after")
    @classmethod
    def _validate_tel(cls, v: str) -> str:
        """電話番号をフォーマットルールに基づき検証する.

        ルールは utils/validator.validate_tel_format に準拠。

        Args:
            v: 入力の電話番号。

        Returns:
            str: 検証済みの電話番号。

        Raises:
            ValueError: 形式に合致しない場合。

        """
        if not validate_tel_format(v):
            msg = "電話番号の形式が不正です。半角数字とハイフンのみ、ハイフンを含み、数字のみ/括弧付きは不可です。"
            raise ValueError(
                msg,
            )
        return v

    # ★追加: 住所の正規化処理
    @field_validator("address", mode="before")
    @classmethod
    def _format_address(cls, v: str) -> str:
        """住所を正規化する.
        
        - 郵便番号を除去
        - 都道府県を補完
        """
        return normalize_address(v)

    # 住所の形式チェック
    @field_validator("address", mode="after")
    @classmethod
    #def _validate_address(cls, v: str) -> str:
    def _validate_address(cls, v: Optional[str]) -> Optional[str]:
        """住所をフォーマットルールに基づき検証する.

        ルールは utils/validator.validate_address_format に準拠。

        Args:
            v: 入力の住所。

        Returns:
            str: 検証済みの住所。

        Raises:
            ValueError: 形式に合致しない場合。

        """
        ##########
        # ★追加: 値がない、または空文字の場合は None を返してチェックをスキップ 2026/01/04(Sun) T.Abe
        ##########
        if v is None or str(v).strip() == "":
            return None
            
        if not validate_address_format(v):
            msg = "住所の形式が不正です。『都/道/府/県』のいずれかを含めてください。"
            raise ValueError(msg)
        return v

    # ★追加: first_name の正規化（空文字をNoneに）
    @field_validator("first_name", mode="before")
    @classmethod
    def _format_first_name(cls, v) -> Optional[str]:
        """first_nameを正規化する."""
        if v is None:
            return None
        s = str(v).strip()
        if s == "" or s == "不明":
            return None
        # 肩書を除去
        import re
        s = re.sub(r"(代表取締役|取締役|社長|会長|専務|常務|理事長|院長|所長|代表)\s*", "", s)
        return s if s else None

    # ★追加: contact_url の正規化（空文字や「不明」をNoneに）
    @field_validator("contact_url", mode="before")
    @classmethod
    def _format_contact_url(cls, v) -> Optional[str]:
        """contact_urlを正規化する."""
        if v is None:
            return None
        s = str(v).strip()
        if s == "" or s == "不明" or not s.startswith("http"):
            return None
        return s


class LLMCompanyInfo(BaseModel):
    """LLMから受け取るための緩い会社情報スキーマ."""

    company: Optional[str] = None
    tel: Optional[str] = None
    address: Optional[str] = None
    first_name: Optional[str] = None
    url: Optional[str] = None
    contact_url: Optional[str] = None
    business: Optional[str] = None
    genre: Optional[str] = None


class ErrorDetail(BaseModel):
    """失敗時のエラー情報."""

    code: str
    message: str


class ExtractResponse(BaseModel):
    """抽出APIの統一レスポンス."""

    success: bool
    data: Optional[CompanyInfo] = None
    error: Optional[ErrorDetail] = None


class URLScore(BaseModel):
    """関連度によってスコア付けされたURL."""

    url: str = Field(
        description="URL. Webコンテキストの取得に用いられた元URLか関連度の高い別ドメインURL",
    )
    score: float = Field(description="URLと企業の関連度")


class URLScoreList(BaseModel):
    """関連度によってスコア付けされたURLのリスト."""

    urls: list[URLScore] = Field(description="URLと企業の関連度スコア情報のリスト")
