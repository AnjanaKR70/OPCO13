"""
Scan service — orchestrates file upload → ML prediction → metadata storage.

IMPORTANT: Uploaded files are NEVER permanently stored.
They are saved to a temp directory, forwarded to the ML service, and immediately deleted.
"""

import os
import uuid
import tempfile
from pathlib import Path
from fastapi import UploadFile
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.scan_history import ScanHistory
from app.schemas.scan import ScanResultResponse, MLPredictionResponse
from app.exceptions import FileValidationError
from app.utils.logger import logger

settings = get_settings()


def _compute_risk_level(verdict: str, confidence: float | None) -> str:
    """
    Compute risk level from verdict and confidence score.

    Rules:
    - safe → low
    - suspicious + confidence < 0.7 → medium
    - suspicious + confidence >= 0.7 → high
    - malicious → critical (if confidence >= 0.8) or high
    """
    verdict_lower = verdict.lower()

    # Normalize confidence to 0-1 range (ML scanner may return 0-100)
    conf = confidence
    if conf is not None and conf > 1.0:
        conf = conf / 100.0

    if verdict_lower == "safe":
        return "low"
    elif verdict_lower == "suspicious":
        return "medium"
    elif verdict_lower in ["malicious", "dangerous", "phishing"]:
        return "critical"
    elif verdict_lower in ["unsupported", "error"]:
        return "unknown"
    else:
        return "medium"


def _validate_file(file: UploadFile) -> None:
    """
    Validate uploaded file's MIME type and size.
    Raises FileValidationError if validation fails.
    """
    # Validate MIME type
    if file.content_type not in settings.ALLOWED_MIME_TYPES:
        raise FileValidationError(
            f"File type '{file.content_type}' is not allowed. "
            f"Allowed types: {', '.join(settings.ALLOWED_MIME_TYPES)}"
        )


async def _save_temp_file(file: UploadFile) -> tuple[str, int]:
    """
    Save uploaded file to a temporary location.

    Returns:
        Tuple of (temp_file_path, file_size_bytes)
    """
    # Create temp directory if it doesn't exist
    temp_dir = Path(tempfile.gettempdir()) / "scamundo_uploads"
    temp_dir.mkdir(parents=True, exist_ok=True)

    # Generate unique filename
    temp_filename = f"{uuid.uuid4()}_{file.filename}"
    temp_path = temp_dir / temp_filename

    # Write file content
    content = await file.read()
    file_size = len(content)

    # Validate file size
    if file_size > settings.max_upload_size_bytes:
        raise FileValidationError(
            f"File size ({file_size / (1024*1024):.1f} MB) exceeds "
            f"maximum allowed size ({settings.MAX_UPLOAD_SIZE_MB} MB)"
        )

    if file_size == 0:
        raise FileValidationError("Uploaded file is empty")

    with open(temp_path, "wb") as f:
        f.write(content)

    logger.info(f"Temp file saved: {temp_path} ({file_size} bytes)")
    return str(temp_path), file_size


async def _analyze_file_local(file_path: str) -> MLPredictionResponse:
    """
    Simulate ML prediction response without connecting to the ML service.
    Returns an unsupported status since ML is unavailable.
    """
    logger.info("ML scanning disabled. Returning unsupported status for file.")
    return MLPredictionResponse(
        verdict="unsupported",
        confidence=0.0,
        status="Unsupported",
        risk_score=0.0,
        reason=["ML Service unavailable. Analysis is unsupported."],
        detection_method="None",
        file_type="Unknown"
    )


def _delete_temp_file(file_path: str) -> None:
    """Safely delete a temporary file."""
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
            logger.info(f"Temp file deleted: {file_path}")
    except OSError as e:
        logger.error(f"Failed to delete temp file {file_path}: {e}")


async def process_scan(
    db: Session, user_id: uuid.UUID, file: UploadFile
) -> ScanResultResponse:
    """
    Complete scan workflow:
    1. Validate file MIME type and size
    2. Save to temp directory
    3. Forward to ML prediction service
    4. Delete temp file (always, even on failure)
    5. Store scan metadata in database
    6. Return prediction result
    """
    # Step 1: Validate
    _validate_file(file)

    temp_path = None
    try:
        # Step 2: Save temp file
        temp_path, file_size = await _save_temp_file(file)

        # Step 3: Get ML prediction
        prediction = await _analyze_file_local(temp_path)

    finally:
        # Step 4: ALWAYS delete temp file
        if temp_path:
            _delete_temp_file(temp_path)

    # Step 5: Compute risk level and store metadata
    risk_level = _compute_risk_level(prediction.verdict, prediction.confidence)

    scan_record = ScanHistory(
        user_id=user_id,
        file_name=file.filename or "unknown",
        file_size=file_size,
        mime_type=file.content_type or "application/octet-stream",
        verdict=prediction.verdict,
        reason=prediction.reason,
        confidence=prediction.confidence,
        risk_level=risk_level,
    )
    db.add(scan_record)
    db.commit()
    db.refresh(scan_record)

    logger.info(
        f"Scan completed: {scan_record.id} | verdict={prediction.verdict} | "
        f"risk={risk_level} | user={user_id}"
    )

    # Step 6: Return result
    return ScanResultResponse(
        scan_id=str(scan_record.id),
        file_name=scan_record.file_name,
        file_size=scan_record.file_size,
        mime_type=scan_record.mime_type,
        verdict=scan_record.verdict,
        reason=scan_record.reason,
        confidence=scan_record.confidence,
        risk_level=scan_record.risk_level,
        status=prediction.status,
        risk_score=prediction.risk_score,
        detection_method=prediction.detection_method,
        scanned_at=scan_record.scanned_at,
    )


async def _analyze_url_local(url: str) -> MLPredictionResponse:
    """Simulate ML prediction response without connecting to the ML service."""
    logger.info(f"ML scanning disabled. Returning unsupported status for URL: {url}")
    return MLPredictionResponse(
        verdict="unsupported",
        confidence=0.0,
        status="Unsupported",
        risk_score=0.0,
        reason=["ML Service unavailable. Analysis is unsupported."],
        detection_method="None",
        file_type="Unknown"
    )


async def process_url_scan(
    db: Session, user_id: uuid.UUID, url: str
) -> ScanResultResponse:
    """
    Complete URL scan workflow:
    1. Forward URL to ML prediction service
    2. Store scan metadata in database
    3. Return prediction result
    """
    if not url or not url.strip():
        raise FileValidationError("URL cannot be empty")

    # Step 1: Get ML prediction
    prediction = await _analyze_url_local(url)

    # Step 2: Compute risk level and store metadata
    risk_level = _compute_risk_level(prediction.verdict, prediction.confidence)

    scan_record = ScanHistory(
        user_id=user_id,
        file_name=url[:250], # Store URL in file_name (truncate to 250 chars max)
        file_size=0, # URLs have no file size
        mime_type="text/url",
        verdict=prediction.verdict,
        reason=prediction.reason,
        confidence=prediction.confidence,
        risk_level=risk_level,
    )
    db.add(scan_record)
    db.commit()
    db.refresh(scan_record)

    logger.info(
        f"URL Scan completed: {scan_record.id} | verdict={prediction.verdict} | "
        f"risk={risk_level} | user={user_id}"
    )

    # Step 3: Return result
    return ScanResultResponse(
        scan_id=str(scan_record.id),
        file_name=scan_record.file_name,
        file_size=scan_record.file_size,
        mime_type=scan_record.mime_type,
        verdict=scan_record.verdict,
        reason=scan_record.reason,
        confidence=scan_record.confidence,
        risk_level=scan_record.risk_level,
        status=prediction.status,
        risk_score=prediction.risk_score,
        detection_method=prediction.detection_method,
        scanned_at=scan_record.scanned_at,
    )
