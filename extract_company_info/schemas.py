from typing import Optional

from pydantic import BaseModel


class ExtractRequest(BaseModel):
    """入力."""

    company: str
    location: str
    industry: str
    genre: str


class CompanyInfo(BaseModel):
    """成功時の会社情報."""

    company: str
    tel: str
    address: str
    first_name: str
    url: str
    contact_url: str
    business: str
    genre: str


class ErrorDetail(BaseModel):
    """失敗時のエラー情報."""

    code: str
    message: str


class ExtractResponse(BaseModel):
    """抽出APIの統一レスポンス."""

    success: bool
    data: Optional[CompanyInfo] = None
    error: Optional[ErrorDetail] = None
