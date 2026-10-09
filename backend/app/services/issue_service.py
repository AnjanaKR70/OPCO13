"""
Issue service — query scan history as "issues" with pagination, filtering, and sorting.
"""

import math
import uuid
from datetime import date, datetime, timezone

from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.models.scan_history import ScanHistory
from app.schemas.issue import IssueResponse, IssueListResponse
from app.utils.logger import logger


def get_issues(
    db: Session,
    user_id: uuid.UUID,
    page: int = 1,
    page_size: int = 20,
    date_from: date | None = None,
    date_to: date | None = None,
) -> IssueListResponse:
    """
    Retrieve scan history formatted as issues for the authenticated user.

    Args:
        db: Database session
        user_id: Authenticated user's ID
        page: Page number (1-indexed)
        page_size: Items per page (max 100)
        date_from: Filter scans from this date (inclusive)
        date_to: Filter scans up to this date (inclusive)

    Returns:
        Paginated issue list sorted by newest first
    """
    # Clamp page_size
    page_size = min(max(page_size, 1), 100)
    page = max(page, 1)

    # Base query
    query = db.query(ScanHistory).filter(ScanHistory.user_id == user_id)

    # Date filters
    if date_from:
        start = datetime(date_from.year, date_from.month, date_from.day, tzinfo=timezone.utc)
        query = query.filter(ScanHistory.scanned_at >= start)

    if date_to:
        # End of day
        end = datetime(
            date_to.year, date_to.month, date_to.day, 23, 59, 59, tzinfo=timezone.utc
        )
        query = query.filter(ScanHistory.scanned_at <= end)

    # Total count (before pagination)
    total = query.count()

    # Sort newest first + paginate
    scans = (
        query.order_by(desc(ScanHistory.scanned_at))
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    total_pages = math.ceil(total / page_size) if total > 0 else 1

    # Map scan records to issue format
    issues = [
        IssueResponse(
            id=str(scan.id),
            heading=_generate_heading(scan),
            description=_generate_description(scan),
            risk_level=scan.risk_level,
            timestamp=scan.scanned_at,
        )
        for scan in scans
    ]

    logger.info(
        f"Issues retrieved: user={user_id} | page={page}/{total_pages} | total={total}"
    )

    return IssueListResponse(
        issues=issues,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )


def _generate_heading(scan: ScanHistory) -> str:
    """Generate a human-readable heading from scan data."""
    is_url = scan.mime_type == "text/url"
    verdict_map = {
        "safe": "URL Scan — Safe" if is_url else "File Scan — Safe",
        "suspicious": "⚠️ Suspicious URL Detected" if is_url else "⚠️ Suspicious File Detected",
        "malicious": "🚨 Malicious URL Detected" if is_url else "🚨 Malicious File Detected",
    }
    return verdict_map.get(scan.verdict.lower(), f"Scan Result: {scan.verdict}")


def _generate_description(scan: ScanHistory) -> str:
    """Generate a detailed description from scan data."""
    is_url = scan.mime_type == "text/url"
    if is_url:
        parts = [f"URL: {scan.file_name}"]
    else:
        parts = [f"File: {scan.file_name} ({scan.mime_type})"]

    if scan.reason:
        parts.append(f"Reason: {scan.reason}")

    if scan.confidence is not None:
        # ML scanner already returns confidence as percentage (e.g. 99.81)
        # If value > 1.0, it's already a percentage; don't multiply again
        conf_pct = scan.confidence if scan.confidence > 1.0 else scan.confidence * 100
        parts.append(f"Confidence: {conf_pct:.1f}%")

    parts.append(f"Risk Level: {scan.risk_level.upper()}")

    return " | ".join(parts)
