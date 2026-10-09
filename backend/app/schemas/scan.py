"""
Pydantic schemas for scan operations.
"""

from datetime import datetime

from pydantic import BaseModel


class UrlScanRequest(BaseModel):
    url: str

class ScanResultResponse(BaseModel):
    """Scan result returned to the frontend."""

    scan_id: str
    file_name: str
    file_size: int
    mime_type: str
    verdict: str
    reason: str | None
    confidence: float | None
    risk_level: str | None
    status: str
    risk_score: float | None
    detection_method: str | None
    scanned_at: datetime

    class Config:
        from_attributes = True


class MLPredictionResponse(BaseModel):
    """Expected response from the internal ML prediction service."""

    verdict: str  # safe, malicious, suspicious
    reason: str | None = None
    confidence: float | None = None
    status: str = "Completed"
    risk_score: float | None = None
    risk_level: str | None = None
    detection_method: str | None = None
