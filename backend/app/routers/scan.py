"""
Scan route — file upload and ML prediction endpoint.
"""

from fastapi import APIRouter, Depends, UploadFile, File
from sqlalchemy.orm import Session

from app.dependencies import get_db, get_current_user
from app.models.user import User
from app.services import scan_service
from app.schemas.scan import UrlScanRequest
from app.response import success_response

router = APIRouter(tags=["Scan"])


@router.post("/scan", summary="Scan a file for threats")
async def scan_file(
    file: UploadFile = File(..., description="File to scan (max 10 MB)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload a file for threat scanning.

    **Workflow:**
    1. Validates file MIME type and size
    2. Temporarily saves the file
    3. Forwards it to the internal ML prediction service
    4. **Immediately deletes the uploaded file** (never permanently stored)
    5. Stores only scan metadata in the database
    6. Returns the prediction result

    **Supported file types:** PDF, APK, text, images, ZIP, JSON

    **Returns:** Verdict (safe/suspicious/malicious), reason, confidence score, and risk level
    """
    result = await scan_service.process_scan(db, current_user.id, file)
    return success_response(
        message="Scan completed successfully",
        data=result.model_dump(),
    )


@router.post("/scan/url", summary="Scan a URL for threats")
async def scan_url(
    payload: UrlScanRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Scan a URL for phishing threats.
    """
    result = await scan_service.process_url_scan(db, current_user.id, payload.url)
    return success_response(
        message="URL scan completed successfully",
        data=result.model_dump(),
    )
