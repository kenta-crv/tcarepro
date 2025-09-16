"""アプリ設定の集中管理（pydantic-settings前提）。.

環境変数から設定を読み込み、アプリ全体で共有する。
"""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    """アプリ設定（pydantic-settings利用）。.

    大文字フィールド名をそのまま環境変数名として解決する。
    """

    # ログ関連
    APP_LOG_FILE: str = str(BASE_DIR / "logs/app.log")
    APP_LOG_MAX_BYTES: int = 1_048_576
    APP_LOG_BACKUP_COUNT: int = 5

    # Google API
    GOOGLE_API_KEY: str

    EXCLUDE_DOMAINS: str = ""

    model_config = SettingsConfigDict(
        env_file=str(BASE_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
