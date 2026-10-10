"""
SCAMഉണ്ടോ — URL Phishing Feature Extractor (v2 – Context-Aware)
================================================================
Extracts lexical and structural features from raw URL strings
for phishing detection without any network requests (pure static analysis).

CHANGELOG v2 (2026-09-22):
- Separated ACTION keywords from BRAND keywords
- Brand presence in registered domain no longer triggers suspicious_keyword_count
- brand_impersonation now uses context-aware domain mismatch logic
- google.com, apple.com etc. no longer penalized for containing brand names
- Feature count remains 50 for backward compatibility
"""

import re
import math
from urllib.parse import urlparse, parse_qs, unquote
from typing import Dict, Any, List

# ─── TLD Risk Tiers ─────────────────────────────────────────────────
# High-risk TLDs frequently abused for phishing campaigns
HIGH_RISK_TLDS = {
    '.tk', '.ml', '.ga', '.cf', '.gq', '.xyz', '.top', '.buzz',
    '.club', '.work', '.loan', '.click', '.link', '.info', '.online',
    '.site', '.website', '.space', '.icu', '.monster', '.rest', '.fit',
    '.cam', '.ooo', '.surf', '.bar', '.quest'
}

# ─── Action/Security Keywords (phishing tactics, NOT brand names) ───
ACTION_KEYWORDS = [
    'login', 'signin', 'sign-in', 'verify', 'verification', 'update',
    'secure', 'account', 'banking', 'confirm', 'password', 'credential',
    'suspend', 'restrict', 'unlock', 'alert', 'notification', 'urgently',
    'wallet', 'crypto', 'bitcoin', 'ethereum', 'binance',
    'free', 'winner', 'prize', 'reward', 'gift', 'bonus',
    'invoice', 'payment', 'refund', 'billing', 'tax',
    'webscr', 'cmd=', 'dispatch', 'redirect', 'track',
    '.php', 'wp-login', 'wp-admin', 'cgi-bin'
]

# ─── Brand Names (context matters – not suspicious by themselves) ───
BRAND_NAMES = [
    'paypal', 'amazon', 'apple', 'microsoft', 'google', 'facebook',
    'netflix', 'instagram', 'whatsapp', 'dropbox', 'icloud', 'linkedin',
    'twitter', 'yahoo', 'ebay', 'chase', 'wellsfargo', 'bankofamerica',
    'onedrive'
]

# ─── Known legitimate brand domains ────────────────────────────────
# Maps brand keyword → set of legitimate registered domains for that brand
BRAND_LEGITIMATE_DOMAINS = {
    'paypal': {'paypal.com', 'paypal.me'},
    'amazon': {'amazon.com', 'amazon.co.uk', 'amazon.de', 'amazon.in', 'amazon.ca',
               'amazon.co.jp', 'amazon.fr', 'amazon.it', 'amazon.es', 'amazon.com.au',
               'amazon.com.br', 'amazon.sg', 'amazonaws.com'},
    'apple': {'apple.com', 'icloud.com'},
    'microsoft': {'microsoft.com', 'live.com', 'outlook.com', 'office.com', 'azure.com',
                   'windows.com', 'xbox.com', 'bing.com', 'msn.com'},
    'google': {'google.com', 'google.co.in', 'google.co.uk', 'google.de', 'google.fr',
               'google.com.au', 'google.co.jp', 'google.ca', 'google.com.br',
               'googleapis.com', 'googleusercontent.com', 'gstatic.com',
               'youtube.com', 'youtu.be', 'gmail.com', 'blogger.com', 'blogspot.com'},
    'facebook': {'facebook.com', 'fb.com', 'fb.me', 'messenger.com'},
    'netflix': {'netflix.com'},
    'instagram': {'instagram.com'},
    'whatsapp': {'whatsapp.com', 'whatsapp.net'},
    'dropbox': {'dropbox.com', 'dropboxusercontent.com'},
    'icloud': {'icloud.com', 'apple.com'},
    'linkedin': {'linkedin.com'},
    'twitter': {'twitter.com', 'x.com', 't.co'},
    'yahoo': {'yahoo.com', 'yahoo.co.jp'},
    'ebay': {'ebay.com', 'ebay.co.uk', 'ebay.de'},
    'chase': {'chase.com'},
    'wellsfargo': {'wellsfargo.com'},
    'bankofamerica': {'bankofamerica.com'},
    'onedrive': {'onedrive.com', 'live.com'},
}

# ─── Obfuscation Patterns ───────────────────────────────────────────
OBFUSCATION_PATTERNS = [
    r'%[0-9a-fA-F]{2}',      # Percent-encoded characters
    r'0x[0-9a-fA-F]+',       # Hex-encoded segments
    r'\d{8,}',               # Very long numeric sequences (IP obfuscation)
    r'data:',                # Data URI scheme
    r'javascript:',          # JS URI scheme
    r'&#\d+;',               # HTML entity encoding
    r'\\x[0-9a-fA-F]{2}',   # Hex escape sequences
]


def is_ip_address(domain: str) -> bool:
    """Check if domain is an IP address (IPv4 or IPv6)."""
    # IPv4
    ipv4_pattern = re.compile(r'^(\d{1,3}\.){3}\d{1,3}$')
    if ipv4_pattern.match(domain):
        return True
    # IPv6
    if ':' in domain and all(c in '0123456789abcdefABCDEF:' for c in domain):
        return True
    # Decimal IP (single large integer)
    try:
        val = int(domain)
        if val > 0:
            return True
    except ValueError:
        pass
    return False


def _get_registered_domain(domain_clean: str) -> str:
    """
    Extract the registered domain (SLD + TLD) from a cleaned domain.
    For example: 'login.paypal.evil.com' -> 'evil.com'
                 'www.google.com' -> 'google.com'
    This is a simple heuristic (last two parts), not a full PSL lookup.
    """
    parts = domain_clean.split('.')
    if len(parts) >= 2:
        return '.'.join(parts[-2:])
    return domain_clean


def extract_url_features(url: str) -> Dict[str, Any]:
    """
    Extracts a comprehensive set of lexical and structural features
    from a raw URL string. No network requests are made.
    
    Returns a dictionary of numeric features suitable for ML classification.
    """
    features = {}
    url_str = str(url).strip()
    url_lower = url_str.lower()

    # ─── Parse URL ───────────────────────────────────────────────
    try:
        parsed = urlparse(url_str)
    except Exception:
        parsed = urlparse('')

    scheme = (parsed.scheme or '').lower()
    netloc = parsed.netloc or ''
    path = parsed.path or ''
    query = parsed.query or ''
    fragment = parsed.fragment or ''

    # Strip port from netloc for domain extraction
    domain = netloc.split(':')[0].lower()
    # Remove 'www.' prefix
    domain_clean = domain.lstrip('www.')

    # Get registered domain for context-aware brand detection
    registered_domain = _get_registered_domain(domain_clean)

    # ─── 1. Length-based Features ────────────────────────────────
    features['url_length'] = len(url_str)
    features['domain_length'] = len(domain)
    features['path_length'] = len(path)
    features['query_length'] = len(query)
    features['fragment_length'] = len(fragment)

    # ─── 2. Character Count Features ─────────────────────────────
    features['num_dots'] = url_str.count('.')
    features['num_hyphens'] = url_str.count('-')
    features['num_underscores'] = url_str.count('_')
    features['num_slashes'] = url_str.count('/')
    features['num_questionmarks'] = url_str.count('?')
    features['num_equals'] = url_str.count('=')
    features['num_ats'] = url_str.count('@')
    features['num_ampersands'] = url_str.count('&')
    features['num_exclamation'] = url_str.count('!')
    features['num_tildes'] = url_str.count('~')
    features['num_commas'] = url_str.count(',')
    features['num_plus'] = url_str.count('+')
    features['num_stars'] = url_str.count('*')
    features['num_hash'] = url_str.count('#')
    features['num_dollar'] = url_str.count('$')
    features['num_percent'] = url_str.count('%')
    features['num_digits'] = sum(c.isdigit() for c in url_str)
    features['num_letters'] = sum(c.isalpha() for c in url_str)

    # Ratio of digits to total length
    features['digit_ratio'] = round(features['num_digits'] / max(len(url_str), 1), 4)
    # Ratio of special characters
    special_count = sum(not c.isalnum() and c not in ('/', ':', '.') for c in url_str)
    features['special_char_ratio'] = round(special_count / max(len(url_str), 1), 4)

    # ─── 3. Protocol Features ────────────────────────────────────
    features['is_https'] = 1 if scheme == 'https' else 0
    features['is_http'] = 1 if scheme == 'http' else 0
    features['has_port'] = 1 if ':' in netloc and netloc.split(':')[-1].isdigit() else 0

    # ─── 4. Domain Features ──────────────────────────────────────
    features['is_ip_address'] = 1 if is_ip_address(domain_clean) else 0
    features['has_at_symbol'] = 1 if '@' in url_str else 0

    # Subdomain analysis
    domain_parts = domain_clean.split('.')
    # TLD is last part, domain is second-to-last, rest are subdomains
    features['subdomain_count'] = max(0, len(domain_parts) - 2)
    features['domain_token_count'] = len(domain_parts)

    # TLD extraction
    tld = ''
    if domain_parts:
        tld = '.' + domain_parts[-1]
    features['tld_length'] = len(tld)
    features['is_high_risk_tld'] = 1 if tld in HIGH_RISK_TLDS else 0

    # Domain entropy (randomness indicator)
    features['domain_entropy'] = round(_shannon_entropy(domain_clean), 4)

    # ─── 5. Path Features ────────────────────────────────────────
    path_tokens = [t for t in path.split('/') if t]
    features['path_token_count'] = len(path_tokens)
    features['max_path_token_length'] = max((len(t) for t in path_tokens), default=0)

    # ─── 6. Query Features ───────────────────────────────────────
    try:
        query_params = parse_qs(query)
    except Exception:
        query_params = {}
    features['query_param_count'] = len(query_params)
    features['query_value_max_length'] = max(
        (len(v) for vals in query_params.values() for v in vals), default=0
    )

    # ─── 7. Redirect Indicators ──────────────────────────────────
    features['has_redirect'] = 1 if any(kw in url_lower for kw in ['redirect', 'redir', 'url=', 'link=', 'goto=', 'return=', 'returl=', 'next=', 'dest=', 'destination=', 'continue=']) else 0
    features['double_slash_redirect'] = url_str.count('//') - 1  # minus the protocol

    # ─── 8. Encoding & Obfuscation ───────────────────────────────
    encoded_chars = len(re.findall(r'%[0-9a-fA-F]{2}', url_str))
    features['encoded_char_count'] = encoded_chars
    features['has_encoded_chars'] = 1 if encoded_chars > 0 else 0

    # Count total obfuscation pattern matches
    obfuscation_hits = sum(len(re.findall(p, url_str)) for p in OBFUSCATION_PATTERNS)
    features['obfuscation_score'] = obfuscation_hits

    # Check if URL decodes differently than the original
    try:
        decoded = unquote(url_str)
        features['url_decode_diff'] = 1 if decoded != url_str else 0
    except Exception:
        features['url_decode_diff'] = 0

    # ─── 9. Suspicious ACTION Keyword Detection (brands excluded) ─
    # Only count action/tactic keywords, NOT brand names
    action_hits = sum(1 for kw in ACTION_KEYWORDS if kw in url_lower)
    features['suspicious_keyword_count'] = action_hits
    features['has_suspicious_keywords'] = 1 if action_hits > 0 else 0

    # ─── 10. Context-Aware Brand Impersonation ───────────────────
    # A brand name in a URL is suspicious ONLY when the registered domain
    # does NOT belong to that brand (= impersonation).
    # e.g. "paypal.evil.com" → brand 'paypal' found, registered domain 'evil.com'
    #      is NOT in paypal's legitimate domains → brand_impersonation = 1
    # e.g. "google.com/search" → brand 'google' found, registered domain 'google.com'
    #      IS in google's legitimate domains → brand_impersonation = 0
    brand_mismatch = 0
    for brand in BRAND_NAMES:
        if brand in url_lower:
            # Check if the registered domain is legitimate for this brand
            legit_domains = BRAND_LEGITIMATE_DOMAINS.get(brand, set())
            if registered_domain not in legit_domains:
                brand_mismatch = 1
                break
    features['brand_impersonation'] = brand_mismatch

    # ─── 11. URL Entropy ─────────────────────────────────────────
    features['url_entropy'] = round(_shannon_entropy(url_str), 4)

    # ─── 12. Shortening Service Detection ────────────────────────
    shorteners = ['bit.ly', 'tinyurl', 'goo.gl', 't.co', 'ow.ly', 'is.gd',
                  'buff.ly', 'adf.ly', 'tiny.cc', 'lnkd.in', 'rb.gy', 'cutt.ly',
                  'shorte.st', 's.id', 'v.gd', 'clck.ru']
    features['is_shortened'] = 1 if any(s in domain_clean for s in shorteners) else 0

    return features


def _shannon_entropy(text: str) -> float:
    """Calculate Shannon entropy of a string."""
    if not text:
        return 0.0
    freq = {}
    for c in text:
        freq[c] = freq.get(c, 0) + 1
    length = len(text)
    entropy = 0.0
    for count in freq.values():
        p = count / length
        if p > 0:
            entropy -= p * math.log2(p)
    return entropy


# ─── Feature Column Names (for ML pipeline alignment) ───────────────
URL_FEATURE_COLUMNS = [
    'url_length', 'domain_length', 'path_length', 'query_length', 'fragment_length',
    'num_dots', 'num_hyphens', 'num_underscores', 'num_slashes', 'num_questionmarks',
    'num_equals', 'num_ats', 'num_ampersands', 'num_exclamation', 'num_tildes',
    'num_commas', 'num_plus', 'num_stars', 'num_hash', 'num_dollar', 'num_percent',
    'num_digits', 'num_letters', 'digit_ratio', 'special_char_ratio',
    'is_https', 'is_http', 'has_port',
    'is_ip_address', 'has_at_symbol', 'subdomain_count', 'domain_token_count',
    'tld_length', 'is_high_risk_tld', 'domain_entropy',
    'path_token_count', 'max_path_token_length',
    'query_param_count', 'query_value_max_length',
    'has_redirect', 'double_slash_redirect',
    'encoded_char_count', 'has_encoded_chars', 'obfuscation_score', 'url_decode_diff',
    'suspicious_keyword_count', 'has_suspicious_keywords',
    'brand_impersonation', 'url_entropy', 'is_shortened'
]


if __name__ == "__main__":
    # Quick self-test
    test_urls = [
        "https://www.google.com/search?q=hello",
        "http://192.168.1.1/admin/login.php?user=admin&pass=1234",
        "https://secure-paypal-login.xyz/verify/account?token=abc123&redirect=http://evil.com",
        "http://bit.ly/3xAbCd",
    ]
    for url in test_urls:
        feats = extract_url_features(url)
        print(f"\n{'='*60}")
        print(f"URL: {url[:70]}...")
        print(f"Features: {len(feats)}")
        for k, v in feats.items():
            print(f"  {k}: {v}")
