import csv
from pathlib import Path
from typing import Optional

import pytest
from pydantic import ValidationError

from models.schemas import CompanyInfo, ExtractRequest


def _split_multi(value: str) -> list[str]:
    """複数値文字列を区切り記号で分割して配列化する.

    区切りは日本語データでよく使われる記号を想定。

    Args:
        value: 区切り付きの文字列。

    Returns:
        list[str]: トリム済みの要素配列（空要素は除去）。

    """
    # 空のときは空配列
    if not value:
        return []
    # 想定される区切り文字
    seps = ["・", "、", "/", "／", "|"]
    for sep in seps:
        if sep in value:
            parts = [p.strip() for p in value.split(sep)]
            return [p for p in parts if p]
    # 区切りが無い場合は単一要素リスト
    return [value.strip()] if value.strip() else []


def _build_dataset_from_csv(
    csv_path: Path,
) -> list[tuple[ExtractRequest, Optional[CompanyInfo]]]:
    """evaluation.csv から抽出用データセットを構築する.

    フォーマット:
        input_* 列から ExtractRequest を、expected_* 列から CompanyInfo を生成する。

    Args:
        csv_path: 読み込み対象のCSVファイルパス。

    Returns:
        list[tuple[ExtractRequest, Optional[CompanyInfo]]]:
        `(ExtractRequest, CompanyInfo | None)` のタプル配列。期待値の
        CompanyInfo のバリデーションに失敗した場合は `None` を格納する。

    """
    # 日本語CSVのためBOM混在も考慮
    with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    dataset: list[tuple[ExtractRequest, Optional[CompanyInfo]]] = []
    for row in rows:
        # 入力（ExtractRequest）は必ず構築する
        req = ExtractRequest(
            customer_id=(row.get("input_customer_id") or f"test_{len(dataset)}").strip(),
            company=(row.get("input_company") or "").strip(),
            location=(row.get("input_location") or "").strip(),
            required_businesses=_split_multi(
                (row.get("input_required_businesses") or "").strip(),
            ),
            required_genre=_split_multi((row.get("input_required_genre") or "").strip()),
        )

        # 期待値（CompanyInfo）は検証に失敗したら None にする
        info: Optional[CompanyInfo]
        try:
            info = CompanyInfo(
                company=(row.get("expected_company") or "").strip(),
                business=(row.get("expected_business") or "").strip(),
                address=(row.get("expected_address") or "").strip(),
                url=(row.get("expected_url") or "").strip(),
                contact_url=((row.get("expected_contact_url") or "").strip() or None),
                first_name=((row.get("expected_first_name") or "").strip() or None),
                genre=(row.get("expected_genre") or "").strip(),
                tel=(row.get("expected_tel") or "").strip(),
            )
        except (ValidationError, ValueError, TypeError):
            # 検証に失敗した場合は None を設定
            info = None

        dataset.append((req, info))

    return dataset


@pytest.fixture
def dataset_url(request: pytest.FixtureRequest) -> str:
    """デフォルトのデータセットCSVパスを返すフィクスチャ.

    テスト側で ``@pytest.mark.parametrize(..., indirect=True)`` を使うことで
    任意のCSVパスに差し替え可能。

    Returns:
        str: CSVパス（デフォルトはラベル付きCSV）。

    """
    # parametrize(indirect=True) から渡された値があればそれを優先
    if hasattr(request, "param"):
        return str(request.param)
    # 既定パス
    return "tests/evaluation_tests/dataset/dataset_sample.csv"


@pytest.fixture
def csv_dataset(
    dataset_url: str,
) -> list[tuple[ExtractRequest, Optional[CompanyInfo]]]:
    """評価用データセット（CSV由来）を返す.

    Args:
        dataset_url: 使用するCSVのパス（パラメタライズで上書き可能）。

    Returns:
        list[tuple[ExtractRequest, Optional[CompanyInfo]]]:
        `(ExtractRequest, CompanyInfo | None)` の配列。

    """
    csv_path = Path(dataset_url)
    return _build_dataset_from_csv(csv_path)


@pytest.fixture
def sample_dataset(
    csv_dataset: list[tuple[ExtractRequest, CompanyInfo]],
) -> tuple[ExtractRequest, CompanyInfo]:
    """CSV先頭の1件をサンプルとして返す.

    既存のテスト互換のために `(ExtractRequest, CompanyInfo)` を単体で返す。

    Args:
        csv_dataset: セッション共有のCSV由来データセット。

    Returns:
        tuple[ExtractRequest, CompanyInfo]: 先頭要素。空の場合は `pytest.skip`。

    """
    if not csv_dataset:
        pytest.skip("CSVデータセットが空です")
    return csv_dataset[0]
