"""agent.extract_company_info の統合テスト.

conftest.py のフィクスチャを用いて入力・期待値を共有する。
外部サービスのモックは行わず、シンプルに入出力を検証する。

出力は、一つの結果CSVに対して追記する（append）。
具体的には、`tests/evaluation_tests/results/{dataset名}.csv` を出力先とし、
各ケースの結果行（`actual_*` と `match_*` および `elapsed_seconds` を含む）を追加する。
初回はヘッダを書き込み、2回目以降はヘッダを保ったまま追記する。
"""

import csv
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import pytest

from agent.agent import extract_company_info
from models.schemas import CompanyInfo, ExtractRequest


def _normalize_url(url: str) -> str:
    """URL末尾のスラッシュを除去して正規化する.

    Args:
        url: 対象のURL文字列。

    Returns:
        str: 末尾のスラッシュを除去したURL。

    """
    # 末尾スラッシュのみを無視して比較したい
    return (url or "").rstrip("/")


def _ensure_columns(fieldnames: list[str], required: list[str]) -> list[str]:
    """CSVヘッダに必要な列を重複なく揃える.

    既存ヘッダに不足があれば末尾に追記し、重複は除去する。

    Args:
        fieldnames: 既存のCSVヘッダ一覧。
        required: 追加で必要なヘッダ一覧。

    Returns:
        list[str]: 不足列を補った最終的なヘッダ一覧。

    """
    exists = list(fieldnames)
    for name in required:
        if name not in exists:
            exists.append(name)
    return exists


def _write_result_to_dataset(  # noqa: PLR0915
    req: ExtractRequest,
    expected: Optional[CompanyInfo],
    actual: CompanyInfo,
    csv_path: Path,
    out_csv_path: Path,
    elapsed_seconds: float,
) -> None:
    """結果CSVに1行追記する（append）。.

    指定CSV（``tests/evaluation_tests/dataset/dataset_labeled_care.csv`` など）を読み込み、
    入力キー（`input_company`, `input_location`）で対象行を特定する。
    対象行の情報をもとに、実行結果列（`actual_*`）と一致判定列（`match_*`）、
    実行時間（`elapsed_seconds`）を含む結果レコードを組み立て、
    ``tests/evaluation_tests/results/{dataset名}.csv`` に対して追記する。

    なお、結果CSVが存在しない場合はヘッダを書き込み、その後に1行追加する。

    Args:
        req: 入力のリクエスト。
        expected: 期待される CompanyInfo。
        actual: 実行結果の CompanyInfo。
        csv_path: 元データセットCSVのパス。
        out_csv_path: 追記先の結果CSVパス（テスト開始時刻で固定）。
        elapsed_seconds: 1件の処理に要した実行時間（秒）。

    Returns:
        None

    """
    if not csv_path.exists():
        # ファイルが無い場合は何もしない
        return

    # CSV読込（BOM考慮）
    with csv_path.open("r", encoding="utf-8-sig", newline="") as rf:
        reader = csv.DictReader(rf)
        rows: list[dict[str, str]] = [dict(r) for r in reader]
        original_fields = list(reader.fieldnames or [])

    # 追加する列名の定義
    actual_cols = [
        "actual_company",
        "actual_address",
        "actual_tel",
        "actual_business",
        "actual_genre",
        "actual_url",
        "actual_first_name",
        "actual_contact_url",
    ]
    extra_cols = [
        "elapsed_seconds",
    ]
    match_cols = [
        "match_company",
        "match_address",
        "match_tel",
        "match_business",
        "match_genre",
        "match_url",
        "match_first_name",
        "match_contact_url",
    ]

    # 最終ヘッダ（元CSVの列 + 実行結果列 + 判定列 + 追加列）
    fieldnames = _ensure_columns(original_fields, [*actual_cols, *match_cols, *extra_cols])

    # 比較に使う値（URLは末尾スラッシュ無視）
    # expected が None の場合は空として扱う
    expected_url = _normalize_url(expected.url) if expected else ""
    actual_url = _normalize_url(actual.url)
    expected_contact = _normalize_url(expected.contact_url or "") if expected else ""
    actual_contact = _normalize_url(actual.contact_url or "")

    # 入力キーが一致する行を1件抽出して、結果行を作る
    target_row = None
    for row in rows:
        if (row.get("input_company") or "").strip() == req.company.strip() and (
            row.get("input_location") or ""
        ).strip() == req.location.strip():
            target_row = dict(row)
            break

    if target_row is None:
        # 一致する行が無い場合は追記しない
        return

    # 実行結果の書き込み
    target_row["actual_company"] = actual.company
    target_row["actual_address"] = actual.address
    target_row["actual_tel"] = actual.tel
    target_row["actual_business"] = actual.business
    target_row["actual_genre"] = actual.genre
    target_row["actual_url"] = actual.url
    target_row["actual_first_name"] = actual.first_name or ""
    target_row["actual_contact_url"] = actual.contact_url or ""
    # 実行時間（秒）
    target_row["elapsed_seconds"] = f"{elapsed_seconds:.3f}"

    # 一致判定（expected が空なら空欄、URLは末尾スラッシュ無視）
    def mark(exp: str, act: str) -> str:
        """一致判定を行う.

        Args:
            exp: 期待値文字列。
            act: 実際値文字列。

        Returns:
            str: マーク（"", "○", "×"）。

        """
        if not (exp or "").strip():
            return ""
        return "○" if (exp.strip() == act.strip()) else "×"

    if expected is None:
        # 期待値が無い場合は一致判定は空欄
        target_row["match_company"] = ""
        target_row["match_address"] = ""
        target_row["match_tel"] = ""
        target_row["match_business"] = ""
        target_row["match_genre"] = ""
        target_row["match_url"] = ""
        target_row["match_first_name"] = ""
        target_row["match_contact_url"] = ""
    else:
        target_row["match_company"] = mark(expected.company, actual.company)
        target_row["match_address"] = mark(expected.address, actual.address)
        target_row["match_tel"] = mark(expected.tel, actual.tel)
        target_row["match_business"] = mark(expected.business, actual.business)
        target_row["match_genre"] = "○" if expected.genre in actual.genre else "×"
        target_row["match_url"] = mark(expected_url, actual_url)
        target_row["match_first_name"] = mark(expected.first_name or "", actual.first_name or "")
        target_row["match_contact_url"] = mark(expected_contact, actual_contact)

    # 出力先（テスト開始時刻を用いた固定パス）
    out_csv = out_csv_path
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    write_header = not out_csv.exists()

    # CSVに追記（UTF-8）
    with out_csv.open("a", encoding="utf-8", newline="") as wf:
        writer = csv.DictWriter(wf, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()
        # 欠損キーがあっても例外にならないよう、フィールド名で整形
        safe_row = {k: target_row.get(k, "") for k in fieldnames}
        writer.writerow(safe_row)


@pytest.mark.parametrize(
    "dataset_url",
    [
        "tests/evaluation_tests/dataset/dataset_sample.csv",
    ],
    indirect=True,
)
def test_extract_company_info_returns_company_info(
    csv_dataset: list[tuple[ExtractRequest, Optional[CompanyInfo]]],
    dataset_url: str,
) -> None:
    """CSVデータセット全件を処理し、実行結果をCSVへ書き出す.

    注意: 外部サービス呼び出しをモックしていないため、ネットワーク環境に依存します。

    Args:
        csv_dataset: `conftest.py` が提供する `(ExtractRequest, CompanyInfo)` のリスト。
        dataset_url: 入出力対象となるデータセットCSVのパス（fixture経由）。

    """
    # テスト開始時刻（UTC）で出力ディレクトリを固定
    test_started_at = datetime.now(timezone.utc)
    dataset_name = Path(dataset_url).stem
    ts_dir = (
        Path("tests/evaluation_tests/results")
        / dataset_name
        / test_started_at.strftime("%Y%m%d_%H%M%S")
    )
    out_csv_path = ts_dir / Path(dataset_url).name

    for req, expected in csv_dataset:
        # SUT の実行
        started_at = datetime.now(timezone.utc)
        try:
            actual = extract_company_info(req)
        except Exception:  # noqa: BLE001, S112
            continue
        finished_at = datetime.now(timezone.utc)
        elapsed_seconds = (finished_at - started_at).total_seconds()

        # 実行結果をCSVに書き戻し（一致判定含む）
        _write_result_to_dataset(
            req=req,
            expected=expected,
            actual=actual,
            csv_path=Path(dataset_url),
            out_csv_path=out_csv_path,
            elapsed_seconds=elapsed_seconds,
        )
