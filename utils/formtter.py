"""文字列の整形ユーティリティ.

会社名や電話番号の表記ゆれを正規化する関数を提供する。

【修正履歴】
- 2026/01/03: normalize_tel_number にハイフン自動挿入処理を追加
- 2026/01/03: normalize_company_name に略称展開・カッコ除去処理を追加
- 2026/01/03: normalize_address 関数を新規追加（都道府県補完）
"""

import re
import unicodedata


# 47都道府県リスト（住所正規化用）
PREFECTURES = [
    "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
    "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
    "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
    "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
    "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
    "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
    "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
]


def normalize_company_name(name: str) -> str:
    """会社名の全角英数字・記号を半角へ、略称を正式名称に展開し、不要な記号を除去する.

    仕様:
    - 全角の英数字・記号は半角へ正規化（NFKC）。
    - 半角/全角スペースなどの空白はすべて削除。
    - 「(株)」「㈱」→「株式会社」、「(有)」「㈲」→「有限会社」等に展開。
    - 残ったカッコ類を除去。

    Args:
        name: 入力の会社名文字列。

    Returns:
        str: 正規化済みの会社名。

    """
    if name is None:
        return ""
    
    # NFKC正規化（全角→半角）
    s = unicodedata.normalize("NFKC", str(name))
    
    # 空白除去
    s = re.sub(r"\s+", "", s)
    
    # 略称を正式名称に展開
    # ㈱ は NFKC で (株) になるので、(株) のみ対応すればOK
    abbreviations = {
        "(株)": "株式会社",
        "(有)": "有限会社",
        "(合)": "合同会社",
        "(資)": "合資会社",
        "(医)": "医療法人",
        "(福)": "社会福祉法人",
        "(社)": "一般社団法人",
        "(財)": "一般財団法人",
    }
    for abbr, full in abbreviations.items():
        s = s.replace(abbr, full)
    
    # 残ったカッコ類を除去（半角・全角両方）
    s = re.sub(r"[()（）\[\]【】「」『』]", "", s)
    
    # 支店・営業所を除去（バリデーションエラー防止）
    # 末尾の「支店」「営業所」「出張所」を除去
    s = re.sub(r"(支店|営業所|出張所)$", "", s)
    
    return s


def normalize_tel_number(tel: str) -> str:
    """電話番号内の数値などを半角へ正規化し、ハイフンを自動挿入する.

    仕様:
    - NFKC 正規化により、全角数字や括弧・ハイフン等も半角へ揃える。
    - ハイフン風の記号を ASCII ハイフンに統一。
    - カッコを除去。
    - ハイフンがない場合、市外局番パターンに基づき自動挿入。

    Args:
        tel: 入力の電話番号文字列。

    Returns:
        str: 正規化済みの電話番号。

    """
    if tel is None:
        return ""
    
    # NFKC正規化
    s = unicodedata.normalize("NFKC", str(tel))
    
    # ハイフン風の記号を ASCII ハイフンに寄せる
    s = re.sub(r"[\u2212\u2010-\u2015\uFF0D−–—]", "-", s)
    
    # カッコを除去
    s = re.sub(r"[()（）]", "", s)
    
    # 数字とハイフン以外を除去
    s = re.sub(r"[^0-9\-]", "", s)
    
    # 連続するハイフンを1つに
    s = re.sub(r"-+", "-", s)
    
    # 先頭・末尾のハイフンを除去
    s = s.strip("-")
    
    # ハイフンが既に含まれていればそのまま返す
    if "-" in s:
        return s
    
    # 数字のみの場合、ハイフンを自動挿入
    digits = s
    
    if len(digits) < 10:
        # 桁数が足りない場合はそのまま返す（バリデーションで弾かれる）
        return s
    
    # フリーダイヤル系（0120, 0800）
    if digits.startswith("0120"):
        if len(digits) >= 10:
            return f"{digits[:4]}-{digits[4:7]}-{digits[7:]}"
    elif digits.startswith("0800"):
        if len(digits) >= 11:
            return f"{digits[:4]}-{digits[4:7]}-{digits[7:]}"
    
    # 携帯電話（070, 080, 090）
    elif digits.startswith(("070", "080", "090")):
        if len(digits) >= 11:
            return f"{digits[:3]}-{digits[3:7]}-{digits[7:]}"
    
    # IP電話（050）
    elif digits.startswith("050"):
        if len(digits) >= 11:
            return f"{digits[:3]}-{digits[3:7]}-{digits[7:]}"
    
    # 2桁市外局番（東京03, 大阪06 等）
    elif digits.startswith(("03", "06")):
        if len(digits) >= 10:
            return f"{digits[:2]}-{digits[2:6]}-{digits[6:]}"
    
    # 3桁市外局番（横浜045, 名古屋052, 札幌011 等）
    elif len(digits) >= 10:
        prefix2 = digits[:2]
        prefix3 = digits[:3]
        
        # 2桁市外局番のリスト
        two_digit_prefixes = {"03", "06"}
        
        # 3桁市外局番のパターン
        three_digit_patterns = [
            "011", "015", "017", "018", "019",
        ]
        if prefix2 in two_digit_prefixes:
            return f"{digits[:2]}-{digits[2:6]}-{digits[6:]}"
        elif prefix3 in three_digit_patterns or (
            prefix2 in {"01", "02", "04", "05", "07", "08", "09"} and 
            prefix3[2] in "23456789"
        ):
            return f"{digits[:3]}-{digits[3:6]}-{digits[6:]}"
        else:
            # 4桁市外局番（地方の市外局番）
            return f"{digits[:4]}-{digits[4:6]}-{digits[6:]}"
    
    return s


def normalize_address(address: str) -> str:
    """住所を正規化し、都道府県を補完する.

    仕様:
    - NFKC 正規化により、全角数字等を半角へ揃える。
    - 郵便番号（〒XXX-XXXX）を除去。
    - 都道府県が含まれていない場合、先頭の文字列から推測して補完。

    Args:
        address: 入力の住所文字列。

    Returns:
        str: 正規化済みの住所。

    """
    if address is None or str(address).strip() == "":
        return ""
    
    # NFKC正規化
    s = unicodedata.normalize("NFKC", str(address))
    
    # 前後の空白除去
    s = s.strip()
    
    # 郵便番号を除去（〒XXX-XXXX または XXX-XXXX）
    s = re.sub(r"〒?\s*\d{3}[-－ー]\d{4}\s*", "", s).strip()
    
    # 都道府県が既に含まれていればそのまま返す
    # 注意: 「道玄坂」の「道」などを誤検出しないよう、都道府県名パターンで判定
    prefecture_pattern = r"(北海道|.{2,3}[都府県])"
    if re.search(prefecture_pattern, s):
        return s
    
    # === 1. 東京23区の場合（最優先で判定） ===
    tokyo_wards = [
        "千代田区", "中央区", "港区", "新宿区", "文京区", "台東区", "墨田区",
        "江東区", "品川区", "目黒区", "大田区", "世田谷区", "渋谷区", "中野区",
        "杉並区", "豊島区", "北区", "荒川区", "板橋区", "練馬区", "足立区",
        "葛飾区", "江戸川区"
    ]
    for ward in tokyo_wards:
        if s.startswith(ward):
            return "東京都" + s
    
    # === 2. 「東京〇〇区」のパターン（東京都を補完） ===
    # 「東京」で始まり、その後に23区が続く場合
    if s.startswith("東京"):
        rest = s[2:]  # 「東京」を除いた部分
        for ward in tokyo_wards:
            if rest.startswith(ward):
                return "東京都" + rest
        # 23区が続かなくても「東京」で始まれば「東京都」を補完
        return "東京都" + rest
    
    # === 3. 主要都市から都道府県を推測（都道府県名より先に判定） ===
    city_to_pref = {
        "札幌市": "北海道",
        "仙台市": "宮城県",
        "さいたま市": "埼玉県",
        "千葉市": "千葉県",
        "横浜市": "神奈川県",
        "川崎市": "神奈川県",
        "相模原市": "神奈川県",
        "新潟市": "新潟県",
        "静岡市": "静岡県",
        "浜松市": "静岡県",
        "名古屋市": "愛知県",
        "京都市": "京都府",
        "大阪市": "大阪府",
        "堺市": "大阪府",
        "神戸市": "兵庫県",
        "岡山市": "岡山県",
        "広島市": "広島県",
        "北九州市": "福岡県",
        "福岡市": "福岡県",
        "熊本市": "熊本県",
    }
    
    for city, pref in city_to_pref.items():
        if s.startswith(city):
            return pref + s
    
    # === 4. 都道府県名を補完（短縮形の場合） ===
    # 注意: 「大阪市」などの主要都市を先に判定しているので、
    #       ここでは「大阪」だけで始まる場合のみ処理
    pref_mapping = {
        "北海": "北海道",
        "青森": "青森県",
        "岩手": "岩手県",
        "宮城": "宮城県",
        "秋田": "秋田県",
        "山形": "山形県",
        "福島": "福島県",
        "茨城": "茨城県",
        "栃木": "栃木県",
        "群馬": "群馬県",
        "埼玉": "埼玉県",
        "千葉": "千葉県",
        "神奈川": "神奈川県",
        "新潟": "新潟県",
        "富山": "富山県",
        "石川": "石川県",
        "福井": "福井県",
        "山梨": "山梨県",
        "長野": "長野県",
        "岐阜": "岐阜県",
        "静岡": "静岡県",
        "愛知": "愛知県",
        "三重": "三重県",
        "滋賀": "滋賀県",
        "京都": "京都府",
        "大阪": "大阪府",
        "兵庫": "兵庫県",
        "奈良": "奈良県",
        "和歌山": "和歌山県",
        "鳥取": "鳥取県",
        "島根": "島根県",
        "岡山": "岡山県",
        "広島": "広島県",
        "山口": "山口県",
        "徳島": "徳島県",
        "香川": "香川県",
        "愛媛": "愛媛県",
        "高知": "高知県",
        "福岡": "福岡県",
        "佐賀": "佐賀県",
        "長崎": "長崎県",
        "熊本": "熊本県",
        "大分": "大分県",
        "宮崎": "宮崎県",
        "鹿児島": "鹿児島県",
        "沖縄": "沖縄県",
    }
    
    # 長い都道府県名から順にマッチ（「神奈川」→「神」の順で判定しないように）
    for pref_short, pref_full in sorted(pref_mapping.items(), key=lambda x: -len(x[0])):
        if s.startswith(pref_short):
            # 「大阪市」など主要都市で始まる場合は既に処理済みなのでスキップ
            rest = s[len(pref_short):]
            # 市区町村名が続くかチェック（数字や特殊文字で始まらない）
            if rest and not rest[0].isdigit():
                return pref_full + rest
    
    # 補完できない場合はそのまま返す（バリデーションで弾かれる）
    return s
