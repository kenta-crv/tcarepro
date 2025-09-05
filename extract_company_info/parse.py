"""テキスト解析ユーティリティ.

ラベル付き行から値を抽出する関数を提供します。
"""

import re


def extract_value_by_label(text: str, label: str) -> str:
    """ラベル付き行から値を抽出するユーティリティ.

    Args:
        text (str): 複数行のテキスト。
        label (str): 検索するラベル名（例: "会社名"）。

    Returns:
        str: ラベルに対応する値。見つからない場合は "不明"。

    """
    if not text:
        return "不明"
    pattern = rf"^[\s\-\*\u30fb・]*{re.escape(label)}[^:：]*[:：]\s*(.+)$"
    for line in (text or "").splitlines():
        m = re.search(pattern, line.strip())
        if m:
            return m.group(1).strip() or "不明"
    return "不明"
