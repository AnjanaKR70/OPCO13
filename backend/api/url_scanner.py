"""
SCAMഉണ്ടോ — URL Phishing Scanner API
======================================
Provides scan_url(url) → structured JSON verdict.
Uses the trained URL phishing model for ML inference,
with heuristic fallback when model files are unavailable.
"""

import os
import sys
import joblib
import numpy as np
import pandas as pd
from pathlib import Path
from typing import Dict, Any, List

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from feature_extraction.url_feature_extractor import extract_url_features, URL_FEATURE_COLUMNS

# ─── Model Selection ──────────────────────────────────────────────
# Default to production, but allow candidate testing via environment variable
URL_MODEL_MODE = os.environ.get("URL_MODEL_MODE", "candidate").lower()

if URL_MODEL_MODE == "candidate":
    print("WARNING: Using CANDIDATE URL model (v3.12) for scanning.")
    SAVED_MODELS_DIR = PROJECT_ROOT / "saved_models" / "url_candidates"
else:
    SAVED_MODELS_DIR = PROJECT_ROOT / "saved_models"

URL_MODEL_PATH = SAVED_MODELS_DIR / "url_model.joblib"
URL_IMPUTER_PATH = SAVED_MODELS_DIR / "url_imputer.joblib"
URL_SCALER_PATH = SAVED_MODELS_DIR / "url_scaler.joblib"
URL_COLS_PATH = SAVED_MODELS_DIR / "url_feature_columns.joblib"

# ─── Cached model loading ────────────────────────────────────────
_cached_model = None
_cached_imputer = None
_cached_scaler = None
_cached_cols = None


def _load_pipeline():
    """Lazy-load and cache the URL model pipeline."""
    global _cached_model, _cached_imputer, _cached_scaler, _cached_cols
    if _cached_model is None:
        _cached_model = joblib.load(URL_MODEL_PATH)
        _cached_imputer = joblib.load(URL_IMPUTER_PATH)
        _cached_scaler = joblib.load(URL_SCALER_PATH)
        _cached_cols = joblib.load(URL_COLS_PATH)
    return _cached_model, _cached_imputer, _cached_scaler, _cached_cols


def _pipeline_available() -> bool:
    """Check if all required model artifacts exist on disk."""
    return all(p.exists() for p in [URL_MODEL_PATH, URL_IMPUTER_PATH, URL_SCALER_PATH, URL_COLS_PATH])


# ─── Risk Reason Generator ──────────────────────────────────────
def get_url_risk_reasons(features: Dict[str, Any]) -> List[str]:
    """
    Generates human-readable risk explanations based on extracted URL features.
    """
    reasons = []

    if features.get('is_ip_address', 0) == 1:
        reasons.append("Uses raw IP address instead of a domain name")

    if features.get('url_length', 0) > 75:
        reasons.append(f"URL length is unusually high ({features['url_length']} characters)")

    if features.get('subdomain_count', 0) > 3:
        reasons.append(f"Excessive subdomains detected ({features['subdomain_count']} levels)")

    if features.get('is_https', 0) == 0 and features.get('is_http', 0) == 1:
        reasons.append("Uses insecure HTTP protocol (no HTTPS encryption)")

    if features.get('has_at_symbol', 0) == 1:
        reasons.append("Contains @ symbol — can redirect to a different host than displayed")

    if features.get('suspicious_keyword_count', 0) > 2:
        reasons.append(f"Multiple phishing keywords detected ({features['suspicious_keyword_count']} matches)")
    elif features.get('has_suspicious_keywords', 0) == 1:
        reasons.append("Suspicious keyword detected in URL structure")

    if features.get('brand_impersonation', 0) == 1:
        reasons.append("Potential brand impersonation in subdomain (e.g. paypal.evil.com)")

    if features.get('is_high_risk_tld', 0) == 1:
        reasons.append("Uses a top-level domain frequently associated with phishing campaigns")

    if features.get('obfuscation_score', 0) > 3:
        reasons.append(f"URL obfuscation patterns detected (score: {features['obfuscation_score']})")

    if features.get('encoded_char_count', 0) > 5:
        reasons.append(f"Heavy URL encoding detected ({features['encoded_char_count']} encoded characters)")

    if features.get('has_redirect', 0) == 1:
        reasons.append("Contains redirect parameters (url=, goto=, return=)")

    if features.get('double_slash_redirect', 0) > 1:
        reasons.append(f"Multiple double-slash redirects detected ({features['double_slash_redirect']})")

    if features.get('is_shortened', 0) == 1:
        reasons.append("Uses a URL shortening service — hides true destination")

    if features.get('has_port', 0) == 1:
        reasons.append("Uses a non-standard port in the URL")

    if features.get('domain_entropy', 0) > 4.0:
        reasons.append(f"High domain entropy ({features.get('domain_entropy', 0):.2f}) — randomly generated domain")

    if features.get('num_hyphens', 0) > 4:
        reasons.append(f"Excessive hyphens in URL ({features['num_hyphens']})")

    if features.get('num_dots', 0) > 5:
        reasons.append(f"Unusual number of dots ({features['num_dots']})")

    if features.get('digit_ratio', 0) > 0.3:
        reasons.append(f"High digit concentration ({features['digit_ratio']:.1%} of URL length)")

    return reasons


# ─── Main API Function ──────────────────────────────────────────
def scan_url(url: str) -> Dict[str, Any]:
    """
    Main URL scanning function. Extracts lexical features,
    runs ML inference, and returns a structured verdict.

    Returns:
        {
            "status": "Safe" | "Suspicious" | "Phishing",
            "confidence": float (0-100),
            "risk_score": int (0-100),
            "reasons": [str, ...]
        }
    """
    try:
        # 1. Extract features
        features = extract_url_features(url)
        reasons = get_url_risk_reasons(features)

        # 2. Check if ML pipeline is available
        if not _pipeline_available():
            return {
                "status": "Unable to Verify",
                "confidence": 0.0,
                "risk_score": 0,
                "reasons": ["URL verification models are currently unavailable."]
            }

        # 3. ML Inference
        model, imputer, scaler, feature_cols = _load_pipeline()

        # Build feature vector
        df = pd.DataFrame([features])
        for col in feature_cols:
            if col not in df.columns:
                df[col] = 0
        X = df[feature_cols].copy()

        X_imp = imputer.transform(X)
        X_scaled = scaler.transform(X_imp)

        prediction = model.predict(X_scaled)[0]

        if hasattr(model, "predict_proba"):
            probs = model.predict_proba(X_scaled)[0]
            confidence = float(probs[prediction] * 100)
            phishing_score = float(probs[1] * 100)
        else:
            confidence = 100.0
            phishing_score = 100.0 if prediction == 1 else 0.0

        # Map prediction to tri-state status
        if len(reasons) > 0:
            if prediction == 1 and phishing_score >= 80:
                status = "Phishing"
            else:
                status = "Suspicious"
        else:
            # No heuristic reasons. Trust the ML model's prediction.
            if prediction == 1:
                status = "Suspicious"
            else:
                status = "Safe"

        # Ensure at least one reason
        if status == "Unable to Verify":
            reasons.append("URL safety cannot be reliably verified due to insufficient data for this domain pattern.")
        elif prediction == 1 and not reasons:
            reasons.append("Model detected structural patterns matching known phishing URLs")
        elif prediction == 0 and not reasons:
            reasons.append("No suspicious URL patterns detected")

        return {
            "status": status,
            "confidence": round(confidence, 1),
            "risk_score": int(round(phishing_score)),
            "reasons": reasons
        }

    except Exception as e:
        return {
            "status": "Error",
            "confidence": 0.0,
            "risk_score": 0,
            "reasons": [f"URL scanning error: {str(e)}"]
        }


if __name__ == "__main__":
    # Quick self-test
    import json
    test_urls = [
        "https://www.google.com/search?q=hello",
        "https://github.com/pulls",
        "https://amazon.com/dp/B08N5M7S6K"
    ]
    for url in test_urls:
        result = scan_url(url)
        print(f"\nURL: {url}")
        print(json.dumps(result, indent=2))
