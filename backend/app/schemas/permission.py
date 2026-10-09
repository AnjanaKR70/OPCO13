"""
Pydantic schemas for user permissions.
"""

from datetime import datetime

from pydantic import BaseModel, Field


class PermissionCreate(BaseModel):
    """Request body for POST /user/permissions"""

    storage_permission: bool = Field(False, description="Storage access granted")
    sms_permission: bool = Field(False, description="SMS access granted")
    phone_permission: bool = Field(False, description="Phone/call access granted")
    gmail_permission: bool = Field(False, description="Gmail/email access granted")


class PermissionUpdate(BaseModel):
    """Request body for PUT /user/permissions"""

    storage_permission: bool | None = Field(None, description="Storage access granted")
    sms_permission: bool | None = Field(None, description="SMS access granted")
    phone_permission: bool | None = Field(None, description="Phone/call access granted")
    gmail_permission: bool | None = Field(None, description="Gmail/email access granted")


class PermissionResponse(BaseModel):
    """Permission data returned in responses."""

    id: str
    user_id: str
    storage_permission: bool
    sms_permission: bool
    phone_permission: bool
    gmail_permission: bool
    updated_at: datetime | None

    class Config:
        from_attributes = True
