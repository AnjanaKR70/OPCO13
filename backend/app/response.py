"""
Standardized API response helpers.
"""

from typing import Any


def success_response(message: str, data: Any = None) -> dict:
    """Build a standardized success response."""
    response = {
        "success": True,
        "message": message,
    }
    if data is not None:
        response["data"] = data
    return response
