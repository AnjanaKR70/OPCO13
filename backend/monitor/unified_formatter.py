"""
Adapts disparate responses from `api.scanner` and `api.url_scanner`
into a unified rigid JSON schema mandated by the frontend layout.
"""
from typing import Dict, Any
from datetime import datetime

def _map_threat_level(status: str) -> str:
    if status == "Safe": return "Low"
    if status == "Suspicious": return "Medium"
    if status in ["Phishing", "Dangerous"]: return "Critical"
    return "Unknown"

def _map_recommendation(status: str, input_type: str) -> str:
    if status == "Safe":
        return "No immediate threats detected. Proceed with normal caution."
        
    if input_type == "URL":
        if status == "Phishing":
            return "DO NOT CLICK! This links to a highly-confident phishing page designed to steal credentials."
        return "Exercise extreme caution. Do not input passwords or personal information on this page."
        
    # Document
    if status == "Dangerous":
        return "DO NOT OPEN! This document contains highly anomalous structural traits typical of malware."
    return "This document executes suspicious scripts or macros. Only open if you explicitly trust the sender."

def format_unified_response(input_type: str, raw_response: Dict[str, Any]) -> Dict[str, Any]:
    """
    Transforms raw module output into the unified monitoring schema:
    {
        "input_type": "...",
        "status": "...",
        "confidence": ...,
        "risk_score": ...,
        "threat_level": "...",
        "category": "...",
        "detected_features": [...],
        "recommendation": "...",
        "timestamp": "..."
    }
    """
    if raw_response.get("status") == "Error":
        return {
            "input_type": input_type,
            "status": "Error",
            "confidence": 0.0,
            "risk_score": 0,
            "threat_level": "Unknown",
            "category": "Error",
            "detected_features": [raw_response.get("error", "Unknown internal error")],
            "recommendation": "Engine fault. Consult system logs.",
            "timestamp": datetime.now().isoformat()
        }

    status = raw_response.get("status", "Safe")
    cat = "Phishing" if input_type == "URL" else "Malware"

    # Some APIs output 'reason', URL API outputs 'reasons'
    features = raw_response.get("reasons", raw_response.get("reason", []))

    return {
        "input_type": input_type,
        "status": status,
        "confidence": raw_response.get("confidence", 0.0),
        "risk_score": raw_response.get("risk_score", 0),
        "threat_level": _map_threat_level(status),
        "category": cat,
        "detected_features": features,
        "recommendation": _map_recommendation(status, input_type),
        "timestamp": datetime.now().isoformat()
    }
