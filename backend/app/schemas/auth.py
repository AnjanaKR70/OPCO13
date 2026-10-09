"""
Pydantic schemas for OTP-based authentication.
"""

import re
from datetime import datetime

from pydantic import BaseModel, Field, field_validator


# Indian phone number regex: must start with +91, then 10 digits starting with 6-9
PHONE_REGEX = re.compile(r"^\+91[6-9]\d{9}$")


class SendOTPRequest(BaseModel):
    """Request body for POST /auth/send-otp"""

    phone_number: str = Field(
        ...,
        examples=["+919876543210"],
        description="Indian phone number (must start with +91, followed by 10 digits)",
    )

    @field_validator("phone_number")
    @classmethod
    def validate_indian_phone(cls, v: str) -> str:
        # Strip whitespace and dashes
        cleaned = v.replace(" ", "").replace("-", "")

        # Must start with +91
        if not cleaned.startswith("+91"):
            raise ValueError(
                "Only Indian numbers are allowed. "
                "Phone number must start with +91"
            )

        if not PHONE_REGEX.match(cleaned):
            raise ValueError(
                "Invalid Indian phone number. "
                "Must be +91 followed by 10 digits starting with 6-9"
            )

        return cleaned


class VerifyOTPRequest(BaseModel):
    """Request body for POST /auth/verify-otp"""

    phone_number: str = Field(
        ...,
        examples=["+919876543210"],
        description="Phone number the OTP was sent to",
    )
    otp: str = Field(
        ...,
        min_length=6,
        max_length=6,
        pattern=r"^\d{6}$",
        examples=["482917"],
        description="6-digit OTP code",
    )

    @field_validator("phone_number")
    @classmethod
    def validate_indian_phone(cls, v: str) -> str:
        cleaned = v.replace(" ", "").replace("-", "")
        if not cleaned.startswith("+91"):
            raise ValueError("Phone number must start with +91")
        if not PHONE_REGEX.match(cleaned):
            raise ValueError("Invalid Indian phone number format")
        return cleaned


class SendOTPResponse(BaseModel):
    """Response after OTP is generated."""

    phone_number: str
    otp_expiry_seconds: int = 300
    message: str = "OTP sent successfully"
    # DEV ONLY: Remove in production
    dev_otp: str | None = Field(
        None,
        description="OTP code shown only in development mode. Remove in production.",
    )


class UserResponse(BaseModel):
    """User data returned in responses."""

    id: str
    full_name: str | None
    phone_number: str
    is_active: bool
    is_new_user: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """Response body after successful OTP verification — includes JWT token."""

    access_token: str
    token_type: str = "bearer"
    user: UserResponse
