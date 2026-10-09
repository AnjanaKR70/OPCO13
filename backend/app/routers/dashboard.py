"""
Dashboard route — returns aggregated scan statistics for the home page.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.dependencies import get_db, get_current_user
from app.models.user import User
from app.services import dashboard_service
from app.response import success_response

router = APIRouter(tags=["Dashboard"])


@router.get("/dashboard/stats", summary="Get dashboard statistics")
def get_dashboard_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns aggregated threat detection statistics for the authenticated user.

    **Time periods:** today, this_week, this_month, all_time

    **Per period data:**
    - `total_scans` — total files scanned
    - `threats_blocked` — malicious + suspicious count
    - `threats` — breakdown by verdict (malicious, suspicious, safe)
    - `risk` — breakdown by risk level (critical, high, medium, low)

    **Returns:** Standard success response with nested stats data.
    """
    stats = dashboard_service.get_dashboard_stats(db, current_user.id)
    return success_response(
        message="Dashboard statistics retrieved successfully",
        data=stats.model_dump(),
    )
