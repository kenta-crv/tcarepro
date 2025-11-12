"""ロギングユーティリティ（サイズローテーション対応）。.

アプリ全体で共通利用するロガーを提供する。
"""

import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

from models.settings import settings


def get_logger() -> logging.Logger:
    """ローテーション付きファイルロガーを返す.

    環境変数で設定可能:
    - `APP_LOG_FILE`: ログファイルパス（既定: `logs/app.log`）。
    - `APP_LOG_MAX_BYTES`: 1ファイルあたりの最大サイズ（既定: 1,048,576）。
    - `APP_LOG_BACKUP_COUNT`: 世代数（既定: 5）。

    Returns:
        logging.Logger: 構成済みロガー。

    """
    logger = logging.getLogger("app")
    if logger.handlers:
        return logger

    log_file = settings.APP_LOG_FILE
    max_bytes = settings.APP_LOG_MAX_BYTES
    backup_count = settings.APP_LOG_BACKUP_COUNT

    # 出力先ディレクトリを作成
    Path(log_file).parent.mkdir(parents=True, exist_ok=True)

    handler = RotatingFileHandler(
        log_file,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8",
    )
    formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    handler.setFormatter(formatter)

    # コンソールハンドラーも追加（リアルタイムでログ確認用）
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.DEBUG)
    
    logger.addHandler(handler)
    logger.addHandler(console_handler)
    logger.setLevel(logging.DEBUG)  # DEBUGレベルで詳細ログ出力
    logger.propagate = False
    return logger
