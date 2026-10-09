"""
Pydantic schemas for issues/scan history listing.
"""

from datetime import datetime

from pydantic import BaseModel


class IssueResponse(BaseModel):
    """Single issue item for the issues list."""

    id: str
    heading: str
    description: str
    risk_level: str
    timestamp: datetime

    class Config:
        from_attributes = True


class IssueListResponse(BaseModel):
    """Paginated issues list."""

    issues: list[IssueResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
