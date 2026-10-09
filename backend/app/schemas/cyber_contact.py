"""
Pydantic schemas for cyber cell contacts.
"""

from datetime import datetime

from pydantic import BaseModel


class CyberContactResponse(BaseModel):
    """Single cyber cell contact."""

    id: str
    name: str
    designation: str | None
    phone: str | None
    email: str | None
    address: str | None
    state: str | None
    website: str | None

    class Config:
        from_attributes = True


class CyberContactListResponse(BaseModel):
    """List of cyber cell contacts."""

    contacts: list[CyberContactResponse]
    total: int
