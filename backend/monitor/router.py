"""
Central Pre-Interaction Monitoring Router.
Simulates an OS-level listener (e.g. Android Accessibility Service) that
intercepts intents, queries the ML framework, and decides to ALLOW or BLOCK.
"""

import sys
from pathlib import Path
from typing import Dict, Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from monitor.config import is_monitoring_enabled
from monitor.unified_formatter import format_unified_response
from api.scanner import scan_file
from api.url_scanner import scan_url

def handle_incoming_intent(app_name: str, payload: str, is_file: bool = False) -> Dict[str, Any]:
    """
    Main hook for intercepting system intents.

    Args:
        app_name (str): "WhatsApp", "Chrome", etc.
        payload (str): The raw URL or a local filepath.
        is_file (bool): Whether the payload should be routed to the Document Scanner.

    Returns:
        Dict: Action ("ALLOW" or "BLOCK_AND_WARN") and unified forensic reporting.
    """
    # 1. Respect Toggles
    if not is_monitoring_enabled(app_name):
        return {
            "action": "ALLOW",
            "report": None,
            "message": f"Monitoring disabled for {app_name}. Bypassing scan."
        }

    # 2. Invoke proper API endpoints
    try:
        if is_file:
            raw_response = scan_file(payload)
            input_type = "Document"
        else:
            raw_response = scan_url(payload)
            input_type = "URL"
            
    except Exception as e:
         return {
            "action": "ALLOW",
            "report": None,
            "message": f"Engine execution failure: {e}"
         }

    # 3. Format Unified Response Schema
    unified_report = format_unified_response(input_type, raw_response)

    # 4. Trigger Automatic Defense Responses
    if unified_report["threat_level"] in ["Critical", "Medium"]:
        return {
            "action": "BLOCK_AND_WARN",
            "report": unified_report,
            "frontend_options": ["Cancel", "Continue Anyway", "Report"]
        }
    else:
        return {
             "action": "ALLOW",
             "report": unified_report,
             "frontend_options": []
        }
