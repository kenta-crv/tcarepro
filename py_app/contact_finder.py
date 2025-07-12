import pandas as pd
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import tldextract
import logging
import sys
import signal
import time
import re
import urllib.parse
import threading
import urllib3
import chardet
import ssl
import json
import os
import argparse
from requests.exceptions import RequestException, SSLError, ConnectTimeout, ReadTimeout

# SSL警告を無効化
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def setup_logging():
    """ロギングシステムの設定"""
    logger = logging.getLogger('contact_finder')
    logger.setLevel(logging.INFO)
    
    file_handler = logging.FileHandler('contact_finder.log')
    file_handler.setLevel(logging.DEBUG)
    
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    
    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)
    
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

logger = setup_logging()

# グローバル設定
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
}

TIMEOUT = 15
DELAY = 1

# グローバルフラグ
stop_requested = False
original_encoding = None

# 進捗ファイルパス
PROGRESS_FILE = 'contact_finder_progress.json'

# 除外ドメインリスト（コード内直接指定）
EXCLUDE_DOMAINS = [
    'suumo.jp',
    'tabelog.com',
    'indeed.com',
    'xn--pckua2a7gp15o89zb.com'
    # 必要に応じて追加してください
]

def is_excluded_domain(url, exclude_domains):
    """除外ドメイン判定（部分一致）"""
    try:
        if not exclude_domains:
            return False
        
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        
        for exclude_domain in exclude_domains:
            if exclude_domain.lower() in domain:
                logger.debug(f"除外ドメイン検出: {url} (除外対象: {exclude_domain})")
                return True
        
        return False
    except Exception as e:
        logger.debug(f"除外ドメイン判定エラー: {e}")
        return False

def detect_encoding(file_path):
    """文字エンコーディング自動検出"""
    try:
        with open(file_path, 'rb') as f:
            rawdata = f.read(100000)
        result = chardet.detect(rawdata)
        encoding = result['encoding']
        confidence = result['confidence']
        logger.info(f"検出された文字エンコーディング: {encoding} (信頼度: {confidence:.2f})")
        return encoding
    except Exception as e:
        logger.warning(f"エンコーディング検出失敗: {e}")
        return 'utf-8'

def normalize_url(url):
    """URL正規化（プロトコル自動追加）"""
    if not url or not isinstance(url, str):
        return None
    
    url = str(url).strip()
    if not url or url.lower() == 'nan':
        return None
    
    if url.startswith(('http://', 'https://')):
        return url
    
    return 'https://' + url

def create_session():
    """シンプル版セッション作成（リトライ機能削除）"""
    session = requests.Session()
    return session

def safe_request(url, **kwargs):
    """シンプル版安全なHTTPリクエスト（SSL/TLS + HTTPフォールバック対応）"""
    session = create_session()
    
    # SSL/TLS設定を段階的に試行
    ssl_configs = [
        {'verify': True},
        {'verify': False},
        {'verify': False, 'allow_redirects': True}
    ]
    
    for ssl_config in ssl_configs:
        try:
            kwargs.update(ssl_config)
            response = session.get(url, **kwargs)
            return response
        except SSLError as ssl_error:
            logger.warning(f"SSL設定 {ssl_config} で失敗: {url}")
            continue
        except (ConnectTimeout, ReadTimeout) as timeout_error:
            logger.warning(f"タイムアウト ({ssl_config}): {url}")
            continue
        except Exception as e:
            logger.debug(f"その他のエラー ({ssl_config}): {url} - {str(e)}")
            continue
    
    # HTTPフォールバック（最後の手段）
    if url.startswith('https://'):
        http_url = url.replace('https://', 'http://')
        try:
            logger.info(f"HTTPフォールバック試行: {http_url}")
            kwargs['verify'] = False
            response = session.get(http_url, **kwargs)
            return response
        except Exception as e:
            logger.error(f"HTTPフォールバックも失敗: {http_url} - {str(e)}")
    
    raise Exception(f"全てのSSL/HTTP方法で失敗: {url}")

def contains_mailto_link(soup, base_url):
    """mailto:リンク検出"""
    mailto_links = []
    for a in soup.find_all('a', href=True):
        href = a['href'].lower().strip()
        if href.startswith('mailto:'):
            text = a.get_text(strip=True)
            mailto_links.append({'href': href, 'text': text})
            logger.debug(f"mailto link found: {href} (text: '{text}')")
    
    if mailto_links:
        logger.info(f"📧 mailto:リンク検出: {len(mailto_links)}件 ({base_url})")
        return True
    
    return False

# 高精度スコアリングシステム
SCORE_CRITERIA = {
    'url_exact_match': 500,
    'text_exact_match': 300,
    'nav_bonus': 200,
    'footer_bonus': 150,
    'url_partial_match': 100,
    'text_partial_match': 60,
    'contact_section': 250,
    'icon_bonus': 100,
    'company_contact_bonus': 200,
    'fragment_bonus': 300,
    'image_alt_bonus': 200,
    'external_form_bonus': 300,
    'encoded_path_bonus': 400,
    'subdirectory_bonus': 150,
    'error_page_bonus': 100,
    'area_map_bonus': 250,
    'external_trusted_bonus': 350,
    'navigation_menu_bonus': 180,
    'ul_list_bonus': 120
}

# 検出パターン
URL_PATTERNS = [
    'contact', 'contacts', 'inquiry', 'inquiries', 'enquiry', 'enquiries',
    'お問い合わせ', '問い合わせ', 'コンタクト', 'contact-us', 'contactus',
    'form', 'support', 'help', 'feedback', 'quest', 'toiawase',
    'publics/index', 'pages', 'mailform', 'preference-form', 'reservation',
    'otoiawase', 'soudan', 'soudankai', 'request', 'application',
    'order', 'estimate', 'mitsumori', 'reserve', 'ask', 'entry',
    'smarts/index', 'detail', 'inq', 'mail', 'cgi-bin/contact',
    'contact.html', 'inquiry.html', 'form.html', 'toiawase.html',
    'publics/index/5', 'pages/3', 'pages/5', 'mail.html',
    'company', 'about', 'corp', 'corporate', 'info', 'information',
    'otoiawase_koujyukai.html'
]

TEXT_PATTERNS = [
    'お問い合わせ', 'お問合せ', '問い合わせ', 'お問い合わせはこちら',
    'コンタクト', 'ご連絡', 'ご相談', 'お気軽に', 'サポート',
    'ヘルプ', 'フォーム', 'メールフォーム', 'お客様窓口', '営業窓口',
    '資料請求', '見積もり', 'お見積り', '予約', 'ご予約',
    'contact', 'contact us', 'inquiry', 'enquiry', 'get in touch',
    'reach us', 'support', 'help', 'feedback', 'ask', 'request',
    'お問い合わせ先', 'アクセス＆お問い合わせ'
]

CONTACT_ICON_PATTERNS = [
    'fa-phone', 'fa-envelope', 'fa-mail', 'fa-contact',
    'icon-phone', 'icon-mail', 'icon-contact',
    'phone', 'mail', 'contact', 'envelope',
    'fas fa-envelope'
]

FRAGMENT_PATTERNS = ['#contact', '#inq', '#inquiry', '#form', '#toiawase', '#section08', '#section7']

INVALID_PATTERNS = [
    r'javascript:\s*void\s*\(\s*0?\s*\)',
    r'javascript:\s*;',
    r'^#[\w]*$',
    r'mailto:',
    r'tel:',
    r'javascript:void\(\d+\)',
    r'javascript:\s*return\s+false',
    r'window\.location',
    r'^\s*$'
]

EXCLUDE_PATTERNS = [
    'contact-lens', 'contract', 'サービス相談', '利用相談',
    '採用', 'recruit', '求人', 'privacy',
    'プライバシーポリシー', '利用規約', 'terms'
]

def normalize_encoded_url(url):
    """URLエンコード正規化"""
    try:
        return urllib.parse.unquote(url, encoding='utf-8')
    except:
        return url

def normalize_domain(url):
    """ドメイン正規化（www.統一）"""
    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        if domain.startswith('www.'):
            domain = domain[4:]
        return domain
    except:
        return ''

def is_contact_external_domain(url, text):
    """拡張版外部フォームサービス許可判定"""
    try:
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        path = parsed.path.lower()
        
        trusted_domains = [
            'secure.multi.ne.jp',
            'ssl.formman.com',
            'form.run',
            'mailform.org',
            'ws.formzu.net',
            'ssl.form-mailer.jp',
            'ssl.xaas3.jp',
            'xaas3.jp',
            'samidare.jp',
            's8377681',
            'm5523948'
        ]
        
        if any(trusted_domain in domain for trusted_domain in trusted_domains):
            contact_indicators = ['inquiry', 'contact', 'form', 'mail', 'inquiryedit']
            if any(indicator in path for indicator in contact_indicators) or \
               any(pattern in text.lower() for pattern in TEXT_PATTERNS):
                logger.debug(f"信頼外部フォームを許可: {url}")
                return True
    except:
        pass
    
    return False

def is_same_domain_enhanced(base_url, extracted_url):
    """強化版ドメインチェック"""
    try:
        base_domain = normalize_domain(base_url)
        extracted_domain = normalize_domain(extracted_url)
        return base_domain == extracted_domain and base_domain != ''
    except:
        return False

def extract_clean_text(element):
    """クリーンテキスト抽出"""
    if not element:
        return ''
    
    element_copy = element.__copy__()
    
    for icon in element_copy.find_all(['i', 'span'], class_=True):
        icon_classes = ' '.join(icon.get('class', []))
        if any(pattern in icon_classes.lower() for pattern in ['fa-', 'icon-', 'glyphicon']):
            icon.decompose()
    
    text = element_copy.get_text(strip=True)
    text = re.sub(r'\s+', ' ', text)
    return text.strip()

def extract_image_alt_text(element):
    """画像altテキスト抽出"""
    alt_texts = []
    images = element.find_all('img')
    for img in images:
        alt = img.get('alt', '').strip()
        if alt:
            alt_texts.append(alt)
    return ' '.join(alt_texts)

def detect_contact_icons(element):
    """コンタクトアイコン検出"""
    if not element:
        return False
    
    icons = element.find_all(['i', 'span'], class_=True)
    for icon in icons:
        icon_classes = ' '.join(icon.get('class', []))
        if any(pattern in icon_classes.lower() for pattern in CONTACT_ICON_PATTERNS):
            return True
    
    return False

def find_image_map_links(soup, base_url):
    """イメージマップ（<area>タグ）検出"""
    area_links = []
    
    for area in soup.find_all('area', href=True):
        href = area['href'].strip()
        coords = area.get('coords', '')
        shape = area.get('shape', '')
        absolute_url = urljoin(base_url, href)
        area_links.append((absolute_url, f'area-map-{shape}', area))
        logger.debug(f"イメージマップ検出: {absolute_url} (coords: {coords})")
    
    if area_links:
        logger.info(f"🗺️ イメージマップリンク検出: {len(area_links)}件")
    
    return area_links

def find_navigation_menu_links(soup, base_url, exclude_domains=None):
    """ナビゲーションメニュー専用検索（ul/li強化対応）"""
    nav_links = []
    
    # 1. ID/クラスにnav, menu, navigationを含む要素
    nav_indicators = ['nav', 'menu', 'navigation', 'gnav', 'header-menu', 'mainmenu']
    
    for indicator in nav_indicators:
        # ID検索
        elements = soup.find_all(attrs={'id': re.compile(indicator, re.I)})
        for element in elements:
            links = extract_links_from_section(element, base_url, exclude_domains)
            if links:
                nav_links.extend(links)
                logger.debug(f"ナビID({indicator})でリンク検出: {len(links)}件")
        
        # クラス検索
        elements = soup.find_all(class_=re.compile(indicator, re.I))
        for element in elements:
            links = extract_links_from_section(element, base_url, exclude_domains)
            if links:
                nav_links.extend(links)
                logger.debug(f"ナビクラス({indicator})でリンク検出: {len(links)}件")
    
    # 2. navimenu系IDの検索（具体例対応）
    navimenu_elements = soup.find_all(attrs={'id': re.compile(r'navimenu|navi.*menu|menu.*navi', re.I)})
    for element in navimenu_elements:
        element_id = element.get('id', '')
        
        # 親要素も含めて検索
        parent = element.find_parent()
        if parent:
            links = extract_links_from_section(parent, base_url, exclude_domains)
            if links:
                nav_links.extend(links)
                logger.debug(f"ナビ親要素({element_id})でリンク検出: {len(links)}件")
        
        # 要素自体も検索
        links = extract_links_from_section(element, base_url, exclude_domains)
        if links:
            nav_links.extend(links)
            logger.debug(f"ナビ要素({element_id})でリンク検出: {len(links)}件")
    
    # 3. 数字付きナビID検索（navimenu1, navimenu2, ...）
    for i in range(1, 21):  # navimenu1からnavimenu20まで
        nav_id = f'navimenu{i}'
        element = soup.find(attrs={'id': nav_id})
        if element:
            # 要素自体を検索
            links = extract_links_from_section(element, base_url, exclude_domains)
            if links:
                nav_links.extend(links)
                logger.debug(f"数字付きナビ({nav_id})でリンク検出: {len(links)}件")
            
            # 親要素も検索
            parent = element.find_parent()
            if parent:
                parent_links = extract_links_from_section(parent, base_url, exclude_domains)
                if parent_links:
                    nav_links.extend(parent_links)
                    logger.debug(f"数字付きナビ親({nav_id})でリンク検出: {len(parent_links)}件")
    
    if nav_links:
        logger.info(f"🧭 ナビゲーションメニューリンク検出: {len(nav_links)}件")
    
    return nav_links

def find_ul_li_links(soup, base_url, exclude_domains=None):
    """UL/LI タグ専用検索"""
    ul_li_links = []
    
    # 1. ULタグ検索
    ul_elements = soup.find_all('ul')
    for ul in ul_elements:
        ul_class = ' '.join(ul.get('class', []))
        ul_id = ul.get('id', '')
        
        links = extract_links_from_section(ul, base_url, exclude_domains)
        if links:
            ul_li_links.extend(links)
            logger.debug(f"ULタグでリンク検出: {len(links)}件 (class: {ul_class}, id: {ul_id})")
    
    # 2. 独立LIタグ検索（親がULでない場合）
    li_elements = soup.find_all('li')
    for li in li_elements:
        # 親がULの場合はスキップ（重複を避けるため）
        if li.find_parent('ul'):
            continue
        
        li_class = ' '.join(li.get('class', []))
        li_id = li.get('id', '')
        
        links = extract_links_from_section(li, base_url, exclude_domains)
        if links:
            ul_li_links.extend(links)
            logger.debug(f"独立LIタグでリンク検出: {len(links)}件 (class: {li_class}, id: {li_id})")
    
    if ul_li_links:
        logger.info(f"📋 UL/LIリンク検出: {len(ul_li_links)}件")
    
    return ul_li_links

def find_fragment_links(base_url, soup):
    """フラグメントリンク検出"""
    fragment_candidates = []
    
    for fragment in FRAGMENT_PATTERNS:
        target_id = fragment[1:]  # '#'を除去
        section = soup.find(attrs={'id': target_id})
        if section:
            fragment_url = urljoin(base_url, fragment)
            fragment_candidates.append((fragment_url, f'section-{target_id}', section))
    
    return fragment_candidates

def is_valid_link_enhanced(href, text, element, base_url, exclude_domains=None):
    """強化版リンク有効性チェック（除外ドメイン対応）"""
    # 除外ドメインチェック（最優先）
    if exclude_domains:
        absolute_url = urljoin(base_url, href)
        if is_excluded_domain(absolute_url, exclude_domains):
            logger.debug(f"除外ドメインによりスキップ: {absolute_url}")
            return False
    
    # フラグメントパターンの特別処理
    if '#' in href:
        fragment = href.split('#')[1].lower()
        if any(pattern[1:] in fragment for pattern in FRAGMENT_PATTERNS):
            return True
    
    # 基本的な無効リンクチェック
    for pattern in INVALID_PATTERNS:
        if pattern != r'^#[\w]*$' or not any(frag[1:] in href for frag in FRAGMENT_PATTERNS):
            if re.search(pattern, href, re.IGNORECASE):
                return False
    
    clean_text = text.lower().strip()
    alt_text = extract_image_alt_text(element)
    combined_text = (clean_text + ' ' + alt_text.lower()).strip()
    
    normalized_href = normalize_encoded_url(href)
    
    # 外部ドメインの特別処理
    try:
        absolute_url = urljoin(base_url, href)
        if not is_same_domain_enhanced(base_url, absolute_url):
            if is_contact_external_domain(absolute_url, combined_text):
                return True
            return False
    except:
        return False
    
    # 「お問い合わせ先」の特別処理
    if '問い合わせ先' in combined_text:
        exclude_urls = ['privacy', 'terms', 'policy']
        if any(pattern in normalized_href.lower() for pattern in exclude_urls):
            return False
        return True
    
    # 除外パターン
    for pattern in EXCLUDE_PATTERNS:
        if pattern.lower() in combined_text:
            return False
    
    return True

def find_contact_section(soup):
    """コンタクトセクション検索"""
    contact_sections = []
    
    for element in soup.find_all(['div', 'section', 'aside'],
                                attrs={'id': re.compile(r'contact', re.I)}):
        contact_sections.append(element)
    
    for element in soup.find_all(['div', 'section', 'aside'],
                                class_=re.compile(r'contact', re.I)):
        contact_sections.append(element)
    
    return contact_sections[0] if contact_sections else None

def extract_links_from_section(section, base_url, exclude_domains=None):
    """セクションリンク抽出（除外ドメイン対応）"""
    links = []
    
    for a in section.find_all('a', href=True):
        href = a['href'].strip()
        text = a.get_text(strip=True)
        
        if is_valid_link_enhanced(href, text, a, base_url, exclude_domains):
            absolute_url = urljoin(base_url, href)
            links.append((absolute_url, text, a))
    
    return links

def deep_contact_search_enhanced(soup, base_url, exclude_domains=None):
    """完全強化版深度優先検索（除外ドメイン対応）"""
    contact_links = []
    
    # 1. 直接コンタクトリンク検索
    contact_links.extend(find_direct_contact_links_enhanced(soup, base_url, exclude_domains))
    
    # 2. イメージマップ検索
    image_map_links = find_image_map_links(soup, base_url)
    
    # イメージマップリンクにも除外ドメインチェック適用
    filtered_image_map_links = []
    for url, text, element in image_map_links:
        if not exclude_domains or not is_excluded_domain(url, exclude_domains):
            filtered_image_map_links.append((url, text, element))
        else:
            logger.debug(f"除外ドメインによりイメージマップリンクスキップ: {url}")
    
    contact_links.extend(filtered_image_map_links)
    
    # 3. コンタクトセクション検索
    contact_section = find_contact_section(soup)
    if contact_section:
        section_links = extract_links_from_section(contact_section, base_url, exclude_domains)
        contact_links.extend(section_links)
    
    # 4. フッター検索
    footer = soup.find('footer')
    if footer:
        footer_links = extract_links_from_section(footer, base_url, exclude_domains)
        contact_links.extend(footer_links)
    
    # 5. ナビゲーション検索（nav, header）
    nav_elements = soup.find_all(['nav', 'header'])
    for nav in nav_elements:
        nav_links = extract_links_from_section(nav, base_url, exclude_domains)
        contact_links.extend(nav_links)
    
    # 6. ナビゲーションメニュー専用検索
    nav_menu_links = find_navigation_menu_links(soup, base_url, exclude_domains)
    contact_links.extend(nav_menu_links)
    
    # 7. UL/LI タグ専用検索
    ul_li_links = find_ul_li_links(soup, base_url, exclude_domains)
    contact_links.extend(ul_li_links)
    
    return contact_links

def find_direct_contact_links_enhanced(soup, base_url, exclude_domains=None):
    """直接コンタクトリンク検索（除外ドメイン対応）"""
    links = []
    
    for a in soup.find_all('a', href=True):
        href = a['href'].strip()
        text = a.get_text(strip=True)
        
        if is_valid_link_enhanced(href, text, a, base_url, exclude_domains):
            absolute_url = urljoin(base_url, href)
            links.append((absolute_url, text, a))
    
    return links

def calculate_enhanced_score(href, text, element, base_url, is_error_page=False):
    """拡張版スコアリング（ナビ/ul/li対応強化）"""
    score = 0
    
    try:
        normalized_href = normalize_encoded_url(href)
        url_path = urlparse(urljoin(base_url, normalized_href)).path.lower()
        clean_text = extract_clean_text(element).lower()
        alt_text = extract_image_alt_text(element).lower()
        combined_text = (clean_text + ' ' + alt_text).strip()
        has_contact_icon = detect_contact_icons(element)
        
        # 404エラーページボーナス
        if is_error_page:
            score += SCORE_CRITERIA['error_page_bonus']
            logger.debug(f"Error page bonus: {href}")
        
        # イメージマップ（<area>）ボーナス
        if element.name == 'area':
            score += SCORE_CRITERIA['area_map_bonus']
            logger.debug(f"Image map area bonus: {href}")
        
        # 外部信頼フォームボーナス
        try:
            if not is_same_domain_enhanced(base_url, href) and is_contact_external_domain(href, combined_text):
                score += SCORE_CRITERIA['external_trusted_bonus']
                logger.debug(f"External trusted form bonus: {href}")
        except:
            pass
        
        # サブディレクトリ内検出ボーナス
        base_path = urlparse(base_url).path.rstrip('/')
        if base_path and base_path in url_path:
            score += SCORE_CRITERIA['subdirectory_bonus']
            logger.debug(f"Subdirectory bonus: {href}")
        
        # フラグメント付きURLの特別処理
        if '#' in href:
            fragment = href.split('#')[1].lower()
            if any(pattern[1:] in fragment for pattern in FRAGMENT_PATTERNS):
                score += SCORE_CRITERIA['fragment_bonus']
                logger.debug(f"Fragment pattern bonus: {href}")
        
        # URLエンコードされたお問い合わせパスの検出
        decoded_path = normalize_encoded_url(url_path)
        if 'お問い合わせ' in decoded_path or 'お問合せ' in decoded_path:
            score += SCORE_CRITERIA['encoded_path_bonus']
            logger.debug(f"Encoded path bonus: {href}")
        
        # 確実なお問い合わせURL（最優先）
        primary_contact_patterns = [
            'contact', 'contacts', 'inquiry', 'inquiries', 'お問い合わせ',
            '問い合わせ', 'toiawase', 'form', 'mailform', 'mail.html', 'mailform',
            'otoiawase_koujyukai.html', 'inquiryedit'
        ]
        
        # 会社情報系URL
        company_patterns = ['company', 'about', 'corp', 'corporate', 'info']
        
        url_score = 0
        text_score = 0
        
        # URL基本スコアリング
        for pattern in primary_contact_patterns:
            if pattern in decoded_path:
                if f'/{pattern}' in decoded_path or f'{pattern}/' in decoded_path or decoded_path.endswith(f'/{pattern}'):
                    url_score = SCORE_CRITERIA['url_exact_match']
                    logger.debug(f"URL exact match: {href} (pattern: {pattern})")
                    break
                else:
                    url_score = SCORE_CRITERIA['url_partial_match']
                    logger.debug(f"URL partial match: {href} (pattern: {pattern})")
        
        # テキスト＋altテキストスコアリング
        contact_text_found = False
        for pattern in TEXT_PATTERNS:
            if pattern in combined_text:
                if pattern == combined_text or combined_text.startswith(pattern):
                    text_score = SCORE_CRITERIA['text_exact_match']
                    contact_text_found = True
                    logger.debug(f"Text exact match: {href} (pattern: {pattern}, text: '{combined_text}')")
                    break
                else:
                    text_score = SCORE_CRITERIA['text_partial_match']
                    contact_text_found = True
                    logger.debug(f"Text partial match: {href} (pattern: {pattern}, text: '{combined_text}')")
        
        # 画像altテキスト特別ボーナス
        if alt_text and any(pattern in alt_text for pattern in ['お問い合わせ', 'お問合せ', '問い合わせ', 'contact']):
            score += SCORE_CRITERIA['image_alt_bonus']
            logger.debug(f"Image alt text bonus: {href} (alt: {alt_text})")
        
        # 会社情報系URLの特別処理
        is_company_url = any(pattern in decoded_path for pattern in company_patterns)
        if is_company_url and contact_text_found and has_contact_icon:
            score += text_score + SCORE_CRITERIA['company_contact_bonus']
            logger.debug(f"Company URL with contact indicators: {href}")
        else:
            score += url_score + text_score
        
        # アイコンボーナス
        if has_contact_icon and contact_text_found:
            score += SCORE_CRITERIA['icon_bonus']
            logger.debug(f"Icon bonus: {href}")
        
        # 位置による加点（ul/li/ナビ対応強化）
        parent = element.find_parent() if element else None
        context_bonus = 0
        
        for level in range(5):
            if not parent or not hasattr(parent, 'get'):
                break
                
            parent_class = ' '.join(parent.get('class', []))
            parent_id = parent.get('id', '')
            parent_tag = parent.name if hasattr(parent, 'name') else ''
            combined = (parent_class + parent_id + parent_tag).lower()
            
            # ナビゲーション系ボーナス
            if any(keyword in combined for keyword in ['nav', 'navigation', 'menu', 'header', 'gnav']):
                context_bonus = max(context_bonus, SCORE_CRITERIA['navigation_menu_bonus'])
                logger.debug(f"Navigation menu bonus: {href} (level: {level})")
            
            # フッター系ボーナス
            elif 'footer' in combined:
                context_bonus = max(context_bonus, SCORE_CRITERIA['footer_bonus'])
                logger.debug(f"Footer bonus: {href} (level: {level})")
            
            # コンタクトセクションボーナス
            elif 'contact' in combined:
                context_bonus = max(context_bonus, SCORE_CRITERIA['contact_section'])
                logger.debug(f"Contact section bonus: {href} (level: {level})")
            
            # ul/liボーナス
            elif parent_tag in ['ul', 'li']:
                context_bonus = max(context_bonus, SCORE_CRITERIA['ul_list_bonus'])
                logger.debug(f"UL/LI list bonus: {href} (level: {level}, tag: {parent_tag})")
            
            parent = parent.find_parent()
        
        score += context_bonus
        
        # 完全除外パターン
        exclude_in_url = [
            'about-us', 'company-profile', 'corporate-info',
            'history', 'profile', '会社概要', '企業情報'
        ]
        
        if any(pattern in decoded_path for pattern in exclude_in_url):
            score = 0
            logger.debug(f"Excluded company info page: {href}")
        
        # テキストによる除外
        exclude_texts = [
            '会社概要', '企業情報', '会社案内', 'about us',
            'company profile', 'corporate information'
        ]
        
        if any(pattern in combined_text for pattern in exclude_texts):
            score = max(0, score - 300)
            logger.debug(f"Text-based exclusion penalty: {href} (text: '{combined_text}')")
        
        # 最終スコアのログ出力
        if score > 0:
            logger.debug(f"Final score: {href} = {score} points")
    
    except Exception as e:
        logger.debug(f"Error calculating enhanced score: {e}")
    
    return score

def search_subdirectory_paths(base_url):
    """サブディレクトリ共通パス検索"""
    global stop_requested
    
    if stop_requested:
        return None
    
    try:
        parsed_base = urlparse(base_url)
        base_path = parsed_base.path.rstrip('/')
        
        subdirectory_paths = [
            '/contact', '/contacts', '/inquiry', '/form', '/mailform',
            '/contact.html', '/inquiry.html', '/form.html', '/index.php',
            '/mailform/index.php', '/contact/index.html', '/inquiry/index.html',
            '/mail.html', '/mailform/otoiawase_koujyukai.html'
        ]
        
        for path in subdirectory_paths:
            if stop_requested:
                return None
            
            try:
                test_url = f"{parsed_base.scheme}://{parsed_base.netloc}{base_path}{path}"
                test_response = safe_request(test_url, headers=HEADERS, timeout=5)
                
                if test_response.status_code == 200:
                    logger.info(f"サブディレクトリパス検出: {test_url}")
                    return test_url
            except:
                continue
        
        return None
    
    except Exception as e:
        logger.debug(f"Error in subdirectory path search: {e}")
        return None

def fallback_search(base_url):
    """親ドメインフォールバック機能"""
    global stop_requested
    
    try:
        if stop_requested:
            return None
        
        parsed_url = urlparse(base_url)
        parent_domain = f"{parsed_url.scheme}://{parsed_url.netloc}/"
        
        if parent_domain != base_url:
            logger.info(f"親ドメインで再検索: {parent_domain}")
            return find_contact_url_enhanced(parent_domain)
    except:
        pass
    
    return None

def print_progress(current, total, url, status):
    """進捗表示"""
    progress = (current / total) * 100
    print(f"\r処理中 [{current}/{total}] {progress:.1f}% | {url} → {status}", end="")

def handle_dynamic_content(url):
    """強化版動的コンテンツ対応（Selenium安定性向上）"""
    global stop_requested
    
    try:
        if stop_requested:
            return None
        
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
        from selenium.webdriver.support.ui import WebDriverWait
        from selenium.webdriver.support import expected_conditions as EC
        from selenium.webdriver.common.by import By
        from selenium.common.exceptions import TimeoutException, WebDriverException
        
        options = Options()
        options.headless = True
        options.add_argument('--no-sandbox')
        options.add_argument('--disable-dev-shm-usage')
        options.add_argument('--disable-gpu')
        options.add_argument('--disable-features=VizDisplayCompositor')
        options.add_argument('--remote-debugging-port=9222')
        options.add_argument('--disable-extensions')
        options.add_argument('--disable-plugins')
        options.add_argument('--disable-images')
        
        driver = None
        try:
            driver = webdriver.Chrome(options=options)
            driver.set_page_load_timeout(20)
            driver.implicitly_wait(5)
            
            driver.get(url)
            
            try:
                WebDriverWait(driver, 10).until(
                    EC.presence_of_element_located((By.TAG_NAME, 'body'))
                )
            except TimeoutException:
                logger.warning(f"Selenium timeout, but proceeding: {url}")
                time.sleep(3)
            
            page_source = driver.page_source
            logger.debug(f"Seleniumでページソース取得成功: {url}")
            return page_source
        
        except WebDriverException as e:
            logger.error(f"Selenium WebDriverException: {url} - {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Selenium unexpected error: {url} - {str(e)}")
            return None
        finally:
            if driver:
                try:
                    driver.quit()
                except:
                    pass
    
    except ImportError:
        logger.warning("Seleniumが利用できません。通常のrequestsを使用します。")
        return None
    except Exception as e:
        if not stop_requested:
            logger.error(f"Selenium setup error: {e}")
        return None

def find_contact_url_enhanced(base_url, exclude_domains=None):
    """ul/li強化版：除外ドメイン対応版"""
    global stop_requested
    
    try:
        if stop_requested:
            return None
        
        time.sleep(DELAY)
        
        # シンプル版安全なリクエスト
        response = safe_request(base_url, headers=HEADERS, timeout=TIMEOUT)
        
        is_error_page = False
        
        # ステータスコード拡張対応（403も解析対象）
        if response.status_code == 200:
            logger.debug(f"正常アクセス: {base_url}")
        elif response.status_code == 404:
            logger.info(f"404エラーページを解析: {base_url}")
            is_error_page = True
        elif response.status_code == 403:
            logger.info(f"403エラーだが解析を継続: {base_url}")
            is_error_page = True
        elif response.status_code >= 400:
            logger.warning(f"エラーステータス{response.status_code}、解析をスキップ: {base_url}")
            return None
        
        if stop_requested:
            return None
        
        # HTMLサイズ判定緩和（50文字以上で解析続行）
        if not response.text or len(response.text) < 50:
            logger.warning(f"HTML取得失敗またはサイズ不足: {base_url}")
            return None
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # 除外ドメイン対応版徹底検索
        all_candidates = deep_contact_search_enhanced(soup, base_url, exclude_domains)
        fragment_candidates = find_fragment_links(base_url, soup)
        all_candidates.extend(fragment_candidates)
        
        # スコアリング（エラーページフラグ付き）
        scored_candidates = []
        for url, text, element in all_candidates:
            if stop_requested:
                return None
            score = calculate_enhanced_score(url, text, element, base_url, is_error_page)
            if score > 0:
                scored_candidates.append((url, score, text))
        
        # フォーム要素の検索
        for form in soup.find_all('form'):
            if stop_requested:
                return None
            
            action = form.get('action', '')
            if action and is_valid_link_enhanced(action, '', form, base_url, exclude_domains):
                try:
                    absolute_url = urljoin(base_url, action)
                    scored_candidates.append((absolute_url, 400, 'form'))
                    logger.debug(f"Form action found: {absolute_url}")
                except:
                    continue
        
        # 2. サブディレクトリ内で見つかった場合は即座に返す
        if scored_candidates:
            scored_candidates.sort(key=lambda x: x[1], reverse=True)
            best_candidate = scored_candidates[0]
            status_msg = "403エラーページ内で検出" if response.status_code == 403 else \
                        "404エラーページ内で検出" if is_error_page else "サブディレクトリ内で検出"
            logger.info(f"{status_msg}: {best_candidate[0]} (score: {best_candidate[1]})")
            return best_candidate[0]
        
        # 3. コンタクトリンクが見つからない場合、mailto:リンクをチェック
        if contains_mailto_link(soup, base_url):
            logger.info("📧 通常のコンタクトリンクは見つからないが、mailto:リンクを検出")
            return 'MAILTO_DETECTED'
        
        # 4. サブディレクトリ内で見つからない場合のみ動的検索
        if stop_requested:
            return None
        
        logger.info(f"サブディレクトリ内で静的検索失敗、動的検索を実行: {base_url}")
        dynamic_html = handle_dynamic_content(base_url)
        
        if dynamic_html and not stop_requested:
            soup = BeautifulSoup(dynamic_html, 'html.parser')
            all_candidates = deep_contact_search_enhanced(soup, base_url, exclude_domains)
            fragment_candidates = find_fragment_links(base_url, soup)
            all_candidates.extend(fragment_candidates)
            
            scored_candidates = []
            for url, text, element in all_candidates:
                if stop_requested:
                    return None
                score = calculate_enhanced_score(url, text, element, base_url, is_error_page)
                if score > 0:
                    scored_candidates.append((url, score, text))
            
            if scored_candidates:
                scored_candidates.sort(key=lambda x: x[1], reverse=True)
                best_candidate = scored_candidates[0]
                logger.info(f"動的検索で検出: {best_candidate[0]} (score: {best_candidate[1]})")
                return best_candidate[0]
            
            # 動的検索でもコンタクトリンクが見つからない場合、再度mailto:チェック
            if contains_mailto_link(soup, base_url):
                logger.info("📧 動的検索でもコンタクトリンクは見つからないが、mailto:リンクを検出")
                return 'MAILTO_DETECTED'
        
        # 5. サブディレクトリ内の共通パス検索
        if stop_requested:
            return None
        
        logger.info(f"サブディレクトリ内共通パス検索: {base_url}")
        subdirectory_result = search_subdirectory_paths(base_url)
        if subdirectory_result:
            return subdirectory_result
        
        # 6. 最後の手段：親ドメインフォールバック
        logger.info(f"サブディレクトリ内で見つからないため親ドメインで検索: {base_url}")
        return fallback_search(base_url)
    
    except Exception as e:
        if not stop_requested:
            logger.error(f"Error in enhanced processing {base_url}: {str(e)}")
        return None

# グローバル変数（中断時の保存用）
current_df = None
output_file = None

# progress.json機能群（安全版）

def load_all_progress():
    """全ファイルの進捗を読み込み"""
    try:
        if os.path.exists(PROGRESS_FILE):
            with open(PROGRESS_FILE, 'r') as f:
                return json.load(f)
        return {}
    except json.JSONDecodeError:
        logger.warning("進捗ファイルが破損しています")
        return {}
    except Exception as e:
        logger.warning(f"進捗ファイル読み込みエラー: {e}")
        return {}

def save_progress_safe(csv_file, last_processed_index):
    """安全版進捗保存（削除機能なし）"""
    global original_encoding
    
    if current_df is not None:
        try:
            # CSV保存
            encoding_to_use = original_encoding if original_encoding else 'utf-8'
            current_df.to_csv(csv_file, index=False, encoding=encoding_to_use)
            logger.debug(f"CSV保存完了（エンコーディング: {encoding_to_use}）")
            
            # 全ファイルの進捗を読み込み
            all_progress = load_all_progress()
            
            # 現在のファイルの進捗を更新
            file_key = os.path.abspath(csv_file)
            all_progress[file_key] = last_processed_index
            
            # progress.jsonに全ファイルの進捗を保存
            with open(PROGRESS_FILE, 'w') as f:
                json.dump(all_progress, f, indent=2)
            
            logger.debug(f"安全版進捗保存完了: {file_key} -> {last_processed_index}")
        
        except Exception as e:
            logger.error(f"進捗保存エラー: {e}")

def get_start_index_safe(csv_file, force_restart=False):
    """安全版開始行決定"""
    if force_restart:
        logger.info("--force指定: 最初から処理を開始します")
        return 0
    
    try:
        all_progress = load_all_progress()
        
        if not all_progress:
            logger.info("進捗ファイルが見つかりません。最初から処理を開始します")
            return 0
        
        file_key = os.path.abspath(csv_file)
        
        if file_key in all_progress:
            last_processed_index = all_progress[file_key]
            start_index = last_processed_index + 1
            logger.info(f"🔄 {os.path.basename(csv_file)}の処理を検出。行{start_index}から自動再開します")
            print(f"✅ {os.path.basename(csv_file)}の前回の続きから自動再開します（行{start_index}から）")
            return start_index
        else:
            logger.info(f"新しいファイル{os.path.basename(csv_file)}を検出。最初から処理を開始します")
            return 0
    
    except Exception as e:
        logger.warning(f"進捗ファイル処理エラー: {e}。最初から処理を開始します")
        return 0

def log_completion_safe(csv_file):
    """安全版完了ログ（削除せず記録のみ）"""
    try:
        logger.info(f"✅ {os.path.basename(csv_file)}の処理が完了しました")
        logger.info(f"📋 進捗ファイル({PROGRESS_FILE})はそのまま保持されます")
        logger.info(f"💡 手動削除したい場合は: --reset オプションを使用してください")
    except Exception as e:
        logger.warning(f"完了ログエラー: {e}")

def show_progress_status():
    """現在の進捗状況を表示"""
    try:
        all_progress = load_all_progress()
        
        if not all_progress:
            print("📋 進捗ファイルなし：全て新規処理です")
            return
        
        print("📋 現在の進捗状況:")
        for file_path, last_index in all_progress.items():
            file_name = os.path.basename(file_path)
            print(f" • {file_name}: 行{last_index}まで完了")
    
    except Exception as e:
        logger.warning(f"進捗状況表示エラー: {e}")

def signal_handler(sig, frame):
    """Ctrl+Cハンドラ"""
    global stop_requested
    stop_requested = True
    print('\n⚠️ 中断要求を受信しました。安全に停止中...')

def main():
    
    # 個別URL検索モード（新規追加）
    if len(sys.argv) == 3 and not sys.argv[1].endswith('.csv'):
        company_name = sys.argv[1]
        domain = sys.argv[2]
        base_url = f"https://{domain}"
        
        try:
            result = find_contact_url_enhanced(base_url, EXCLUDE_DOMAINS)
            if result and result != 'MAILTO_DETECTED':
                print(result)
            elif result == 'MAILTO_DETECTED':
                print('MAILTO_DETECTED')
        except Exception as e:
            pass  # エラー時は何も出力しない
        
        return
    
    
    """コード内直接指定方式メイン処理"""
    global current_df, output_file, stop_requested, original_encoding
    
    # 引数無し対応のargparse設定
    parser = argparse.ArgumentParser(description='企業お問い合わせURL自動抽出ツール（コード内直接指定版）')
    parser.add_argument('csv_file', nargs='?', help='処理対象のCSVファイルパス')  # nargs='?' で optional に
    parser.add_argument('--force', action='store_true', help='最初から処理を開始します（進捗無視）')
    parser.add_argument('--reset', action='store_true', help='進捗ファイルを削除して終了します')
    parser.add_argument('--status', action='store_true', help='現在の進捗状況を表示して終了します')
    
    args = parser.parse_args()
    
    # --status コマンド処理
    if args.status:
        show_progress_status()
        sys.exit(0)
    
    # --reset コマンド処理
    if args.reset:
        if os.path.exists(PROGRESS_FILE):
            os.remove(PROGRESS_FILE)
            logger.info(f"進捗ファイル({PROGRESS_FILE})を削除しました")
            print(f"✅ 進捗ファイル({PROGRESS_FILE})を削除しました")
        else:
            print(f"✅ 進捗ファイル({PROGRESS_FILE})は存在しませんでした")
        sys.exit(0)
    
    # csv_file が指定されていない場合のチェック
    if not args.csv_file:
        print("処理対象のCSVファイルを指定してください")
        print("例: python3 contact_finder.py your_data.csv")
        sys.exit(1)
    
    csv_file = args.csv_file
    
    if not os.path.exists(csv_file):
        logger.error(f"エラー: ファイル '{csv_file}' が見つかりません")
        print(f"エラー: ファイル '{csv_file}' が見つかりません")
        sys.exit(1)
    
    try:
        # 除外ドメインの設定（コード内直接指定）
        exclude_domains = EXCLUDE_DOMAINS
        
        if exclude_domains:
            logger.info(f"🚫 除外ドメイン機能有効: {len(exclude_domains)}件のドメインを除外対象とします")
            print(f"🚫 除外ドメイン機能有効: {len(exclude_domains)}件のドメインを除外対象とします")
            print(f"📝 除外ドメイン: {', '.join(exclude_domains)}")
        else:
            logger.info("除外ドメイン機能無効: すべてのドメインを処理対象とします")
            print("除外ドメイン機能無効: すべてのドメインを処理対象とします")
        
        # 安全版自動再開ロジック
        start_index = get_start_index_safe(csv_file, args.force)
        
        # 元のエンコーディングを検出・保存
        original_encoding = detect_encoding(csv_file)
        
        # CSV読み込み（元エンコーディング使用）
        try:
            df = pd.read_csv(csv_file, encoding=original_encoding)
            logger.info(f"元エンコーディングで読み込み成功: {original_encoding}")
        except UnicodeDecodeError:
            # フォールバック処理
            fallback_encodings = ['shift-jis', 'cp932', 'euc-jp', 'iso-2022-jp', 'latin1']
            for fallback_encoding in fallback_encodings:
                try:
                    logger.info(f"フォールバックエンコーディングで再試行: {fallback_encoding}")
                    df = pd.read_csv(csv_file, encoding=fallback_encoding)
                    original_encoding = fallback_encoding
                    logger.info(f"フォールバックエンコーディングで成功: {original_encoding}")
                    break
                except:
                    continue
            else:
                logger.error("全てのエンコーディングで失敗")
                raise Exception("サポートされている文字エンコーディングで読み込めませんでした")
        
        current_df = df
        output_file = csv_file
        
        logger.info(f"CSVファイル読み込み完了: {len(df)}行 (エンコーディング: {original_encoding})")
        
        # F列（インデックス5）の確認
        if len(df.columns) <= 5:
            logger.error("F列が見つかりません")
            return
        
        # AF列（インデックス31）の確認・作成
        af_col_index = 31
        while len(df.columns) <= af_col_index:
            df[f'Column_{len(df.columns)}'] = ''
        
        total_rows = len(df)
        processed = 0
        skipped = 0
        found = 0
        mailto_detected = 0
        excluded_count = 0  # 除外カウンタ追加
        
        logger.info(f"コード内直接指定版処理開始: 合計{total_rows}行 (開始行: {start_index})")
        
        # メイン処理ループ
        for index, row in df.iterrows():
            # 開始行までスキップ
            if index < start_index:
                skipped += 1
                continue
            
            # 中断チェック
            if stop_requested:
                print("\n🛑 処理を中断します...")
                save_progress_safe(csv_file, index - 1)
                return
            
            # 元のシンプルなスキップ判定を維持（添付ファイルと同じ）
            if pd.notna(df.iloc[index, af_col_index]) and str(df.iloc[index, af_col_index]).strip() != '':
                skipped += 1
                continue
            
            # URL取得と正規化
            raw_url = df.iloc[index, 5]  # F列
            url = normalize_url(raw_url)
            
            if not url:
                df.iloc[index, af_col_index] = None
                processed += 1
                continue
            
            # 除外ドメインチェック（最優先）
            if exclude_domains and is_excluded_domain(url, exclude_domains):
                df.iloc[index, af_col_index] = '除外ドメイン'
                excluded_count += 1
                processed += 1
                logger.info(f"🚫 除外ドメインによりスキップ: {url}")
                continue
            
            # 進捗表示
            print_progress(index+1, total_rows, str(url), "処理中...")
            logger.info(f"処理中 ({index+1}/{total_rows}): {url}")
            
            # 中断チェック（ネットワーク処理前）
            if stop_requested:
                print("\n🛑 ネットワーク処理前に中断...")
                save_progress_safe(csv_file, index - 1)
                return
            
            # 除外ドメイン対応版検索実行
            contact_url = find_contact_url_enhanced(str(url), exclude_domains)
            
            # 中断チェック（処理後）
            if stop_requested:
                print("\n🛑 処理完了後に中断...")
                if contact_url == 'MAILTO_DETECTED':
                    df.iloc[index, af_col_index] = 'メーラー起動リンクのため検出不可'
                else:
                    df.iloc[index, af_col_index] = contact_url if contact_url else None
                save_progress_safe(csv_file, index)
                return
            
            # 結果判定と文言設定
            if contact_url == 'MAILTO_DETECTED':
                result = 'メーラー起動リンクのため検出不可'
                mailto_detected += 1
                logger.info(f"📧 メーラー起動リンクのため検出不可: {url}")
            elif contact_url:
                result = contact_url
                found += 1
                logger.info(f"✅ 検出: {result}")
            else:
                result = None
                logger.info(f"❌ 検出不可（空欄で出力）")
            
            df.iloc[index, af_col_index] = result
            processed += 1
            
            # 安全版随時保存
            if processed % 10 == 0:
                save_progress_safe(csv_file, index)
                logger.info(f"進捗保存: {processed}件処理、{found}件検出、{mailto_detected}件mailto、{excluded_count}件除外、{skipped}件スキップ")
        
        # 安全版最終保存
        save_progress_safe(csv_file, total_rows - 1)
        
        # 完了ログ（削除せず記録のみ）
        log_completion_safe(csv_file)
        
        success_rate = (found / processed * 100) if processed > 0 else 0
        mailto_rate = (mailto_detected / processed * 100) if processed > 0 else 0
        exclude_rate = (excluded_count / processed * 100) if processed > 0 else 0
        
        logger.info(f"🎉 コード内直接指定版処理完了: {processed}件処理、{found}件検出（成功率{success_rate:.1f}%）、{mailto_detected}件mailto（{mailto_rate:.1f}%）、{excluded_count}件除外（{exclude_rate:.1f}%）、{skipped}件スキップ")
        
        print(f"\n🎉 処理完了！")
        print(f"✅ 検出成功: {found}件 ({success_rate:.1f}%)")
        print(f"📧 メール検出: {mailto_detected}件 ({mailto_rate:.1f}%)")
        print(f"🚫 除外ドメイン: {excluded_count}件 ({exclude_rate:.1f}%)")
        print(f"⏭️ スキップ: {skipped}件")
        print(f"📝 除外ドメイン: {', '.join(exclude_domains) if exclude_domains else 'なし'}")
    
    except KeyboardInterrupt:
        logger.info("\n🛑 KeyboardInterrupt で中断...")
        save_progress_safe(csv_file, index if 'index' in locals() else -1)
    except Exception as e:
        logger.error(f"エラー: {str(e)}")
        save_progress_safe(csv_file, index if 'index' in locals() else -1)

if __name__ == '__main__':
    # シグナルハンドラーの登録
    signal.signal(signal.SIGINT, signal_handler)
    logger.info(f"コード内直接指定版処理開始")
    main()
    logger.info("✨ 全処理が完了しました")
