#!/usr/bin/env python3
"""
修正版 formtter.py / schemas.py のテストスクリプト

使用方法:
    python test_normalization.py

このスクリプトは以下をテストします:
1. 電話番号の正規化（ハイフン自動挿入）
2. 会社名の正規化（略称展開、カッコ除去）
3. 住所の正規化（都道府県補完）
"""

import sys
sys.path.insert(0, '.')

from utils.formtter import normalize_company_name, normalize_tel_number, normalize_address
from utils.validator import validate_company_format, validate_tel_format, validate_address_format


def test_tel_normalization():
    """電話番号の正規化テスト"""
    print("=" * 60)
    print("【電話番号の正規化テスト】")
    print("=" * 60)
    
    test_cases = [
        # (入力, 期待される出力, 説明)
        ("0312345678", "03-1234-5678", "東京の市外局番（ハイフンなし）"),
        ("０３−１２３４−５６７８", "03-1234-5678", "全角数字・全角ハイフン"),
        ("03(1234)5678", "03-1234-5678", "カッコ付き"),
        ("03-1234-5678", "03-1234-5678", "正常なフォーマット（変更なし）"),
        ("0120123456", "0120-123-456", "フリーダイヤル"),
        ("09012345678", "090-1234-5678", "携帯電話"),
        ("0451234567", "045-123-4567", "横浜（3桁市外局番）"),
        ("0527654321", "052-765-4321", "名古屋（3桁市外局番）"),
        ("0112345678", "011-234-5678", "札幌"),
    ]
    
    all_passed = True
    for input_val, expected, description in test_cases:
        result = normalize_tel_number(input_val)
        is_valid = validate_tel_format(result)
        status = "✅" if result == expected and is_valid else "❌"
        if result != expected or not is_valid:
            all_passed = False
        print(f"{status} {description}")
        print(f"   入力: {input_val}")
        print(f"   出力: {result} (期待: {expected})")
        print(f"   バリデーション: {'OK' if is_valid else 'NG'}")
        print()
    
    return all_passed


def test_company_normalization():
    """会社名の正規化テスト"""
    print("=" * 60)
    print("【会社名の正規化テスト】")
    print("=" * 60)
    
    test_cases = [
        # (入力, 期待される出力, 説明)
        ("（株）テスト", "株式会社テスト", "全角カッコ略称"),
        ("(株)テスト", "株式会社テスト", "半角カッコ略称"),
        ("㈱テスト", "株式会社テスト", "丸囲み略称"),
        ("テスト　株式会社", "テスト株式会社", "全角スペースあり"),
        ("株式会社 テスト", "株式会社テスト", "半角スペースあり"),
        ("株式会社テスト（東京支店）", "株式会社テスト東京", "カッコ付き支店名→除去"),
        ("ＡＢＣＤ株式会社", "ABCD株式会社", "全角英字"),
        ("株式会社テスト", "株式会社テスト", "正常なフォーマット"),
    ]
    
    all_passed = True
    for input_val, expected, description in test_cases:
        result = normalize_company_name(input_val)
        is_valid = validate_company_format(result)
        status = "✅" if result == expected and is_valid else "❌"
        if result != expected or not is_valid:
            all_passed = False
        print(f"{status} {description}")
        print(f"   入力: {input_val}")
        print(f"   出力: {result} (期待: {expected})")
        print(f"   バリデーション: {'OK' if is_valid else 'NG'}")
        print()
    
    return all_passed


def test_address_normalization():
    """住所の正規化テスト"""
    print("=" * 60)
    print("【住所の正規化テスト】")
    print("=" * 60)
    
    test_cases = [
        # (入力, 期待される出力, 説明)
        ("東京渋谷区道玄坂1-1-1", "東京都渋谷区道玄坂1-1-1", "東京都なし→補完"),
        ("渋谷区道玄坂1-1-1", "東京都渋谷区道玄坂1-1-1", "23区から補完"),
        ("〒150-0043 東京都渋谷区道玄坂1-1-1", "東京都渋谷区道玄坂1-1-1", "郵便番号除去"),
        ("大阪市北区梅田1-1-1", "大阪府大阪市北区梅田1-1-1", "大阪市から補完"),
        ("横浜市中区1-1-1", "神奈川県横浜市中区1-1-1", "横浜市から補完"),
        ("神奈川県横浜市中区1-1-1", "神奈川県横浜市中区1-1-1", "正常なフォーマット"),
        ("北海道札幌市中央区1-1-1", "北海道札幌市中央区1-1-1", "北海道（変更なし）"),
    ]
    
    all_passed = True
    for input_val, expected, description in test_cases:
        result = normalize_address(input_val)
        is_valid = validate_address_format(result)
        status = "✅" if result == expected and is_valid else "❌"
        if result != expected or not is_valid:
            all_passed = False
        print(f"{status} {description}")
        print(f"   入力: {input_val}")
        print(f"   出力: {result} (期待: {expected})")
        print(f"   バリデーション: {'OK' if is_valid else 'NG'}")
        print()
    
    return all_passed


def main():
    print("\n" + "=" * 60)
    print("修正版 formtter.py テストスイート")
    print("=" * 60 + "\n")
    
    results = []
    results.append(("電話番号", test_tel_normalization()))
    results.append(("会社名", test_company_normalization()))
    results.append(("住所", test_address_normalization()))
    
    print("\n" + "=" * 60)
    print("【テスト結果サマリー】")
    print("=" * 60)
    
    all_passed = True
    for name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {name}: {status}")
        if not passed:
            all_passed = False
    
    print()
    if all_passed:
        print("🎉 全てのテストに合格しました！")
    else:
        print("⚠️ 一部のテストが失敗しました。修正が必要です。")
    
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
