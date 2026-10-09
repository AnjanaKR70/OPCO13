"""
Issues route — paginated scan history presented as security issues.
"""

from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.dependencies import get_db, get_current_user
from app.models.user import User
from app.services import issue_service
from app.response import success_response

router = APIRouter(tags=["Issues"])


@router.get("/issues", summary="Get scan history as issues")
def get_issues(
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page (max 100)"),
    date_from: date | None = Query(None, description="Filter from date (YYYY-MM-DD)"),
    date_to: date | None = Query(None, description="Filter to date (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = issue_service.get_issues(
        db=db,
        user_id=current_user.id,
        page=page,
        page_size=page_size,
        date_from=date_from,
        date_to=date_to,
    )

    return success_response(
        message="Issues retrieved successfully",
        data=result.model_dump(),
    )
