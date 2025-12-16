
import re

url_pattern = r'https?://[a-zA-Z0-9.-]+(?:\.[a-zA-Z]{2,})+(?:/[^\s<>"]*)?'

def _is_valid_url(url: str) -> bool:
    """URLが有効かどうかを判定する."""
    # リダイレクトURLを除外
    if 'grounding-api-redirect' in url:
        return False
    # スキームとドメインを含む必要がある
    if url.count('/') < 2:
        return False
    # ドメインにドットを含む必要がある
    try:
        domain = url.split('//')[1].split('/')[0]
        if '.' not in domain:
            return False
    except (IndexError, AttributeError):
        return False
    return True

test_urls = [
    "https://example.com",
    "https://example.tech",
    "https://example.site",
    "https://foo.bar.baz",
    "http://test.co.jp",
    "https://example.com/foo/bar",
    "https://日本語.com", # regex might exclude this, but we want to know
    "https://grounding-api-redirect.google.com",
    "invalid-url"
]

print("Regex Testing:")
for text in test_urls:
    match = re.search(url_pattern, text)
    if match:
        extracted = match.group(0)
        valid = _is_valid_url(extracted)
        print(f"'{text}' -> Extracted: '{extracted}', Valid: {valid}")
    else:
        print(f"'{text}' -> No match")
