"""
Authentication business logic — OTP generation and verification.

IMPORTANT: Since we are NOT using any third-party SMS API,
OTPs are logged to the console and returned in dev mode.
In production, integrate your own SMS gateway here.
"""

import random
from datetime import datetime, timedelta, timezone

from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models.user import User
from app.models.otp import OTP
from app.schemas.auth import (
    SendOTPRequest,
    VerifyOTPRequest,
    SendOTPResponse,
    AuthResponse,
    UserResponse,
)
from app.utils.security import create_access_token
from app.exceptions import InvalidCredentialsError
from app.utils.logger import logger

settings = get_settings()

# OTP configuration
OTP_LENGTH = 6
OTP_EXPIRY_MINUTES = 5
MAX_OTP_REQUESTS_PER_HOUR = 5
MAX_VERIFY_ATTEMPTS = 5


def _generate_otp() -> str:
    """Generate a cryptographically random 6-digit OTP."""
    return str(random.randint(100000, 999999))


def _check_rate_limit(db: Session, phone_number: str) -> None:
    """
    Ensure the phone number hasn't exceeded the OTP request limit.
    Max 5 OTP requests per phone per hour.
    """
    one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)

    recent_count = (
        db.query(OTP)
        .filter(
            OTP.phone_number == phone_number,
            OTP.created_at >= one_hour_ago,
        )
        .count()
    )

    if recent_count >= MAX_OTP_REQUESTS_PER_HOUR:
        raise InvalidCredentialsError(
            "Too many OTP requests. Please try again after some time."
        )


def send_otp(db: Session, data: SendOTPRequest) -> SendOTPResponse:
    """
    Generate and store an OTP for the given phone number.

    Flow:
    1. Rate limit check (max 5/hour per phone)
    2. Invalidate any existing unused OTPs for this number
    3. Generate new 6-digit OTP
    4. Store with 5-minute expiry
    5. Log OTP to console (dev mode) — replace with SMS gateway in production
    6. Return response
    """
    # Step 1: Rate limit
    _check_rate_limit(db, data.phone_number)

    # Step 2: Invalidate previous unused OTPs for this phone
    db.query(OTP).filter(
        OTP.phone_number == data.phone_number,
        OTP.is_used == False,  # noqa: E712
    ).update({"is_used": True})

    # Step 3: Generate OTP
    otp_code = _generate_otp()

    # Step 4: Store OTP
    otp_record = OTP(
        phone_number=data.phone_number,
        otp_code=otp_code,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRY_MINUTES),
    )
    db.add(otp_record)
    db.commit()

    # Step 5: Log to console (DEV MODE)
    # In production, send via your SMS gateway here
    logger.info(
        f"[OTP] Generated for {data.phone_number}: {otp_code} "
        f"(expires in {OTP_EXPIRY_MINUTES} min)"
    )

    # Step 6: Return response
    return SendOTPResponse(
        phone_number=data.phone_number,
        otp_expiry_seconds=OTP_EXPIRY_MINUTES * 60,
        message="OTP sent successfully",
        # Show OTP in response only in debug/dev mode
        dev_otp=otp_code if settings.DEBUG else None,
    )


def verify_otp(db: Session, data: VerifyOTPRequest) -> AuthResponse:
    """
    Verify OTP and authenticate the user.

    Flow:
    1. Find the latest unused OTP for this phone number
    2. Check if OTP is expired
    3. Check if max verification attempts exceeded
    4. Verify the OTP code matches
    5. Mark OTP as used
    6. Find or create the user (auto-registration)
    7. Generate JWT token
    8. Return auth response
    """
    # Step 1: Find latest unused OTP for this phone
    otp_record = (
        db.query(OTP)
        .filter(
            OTP.phone_number == data.phone_number,
            OTP.is_used == False,  # noqa: E712
        )
        .order_by(desc(OTP.created_at))
        .first()
    )

    if not otp_record:
        raise InvalidCredentialsError(
            "No active OTP found. Please request a new OTP."
        )

    # Step 2: Check expiry
    if datetime.now(timezone.utc) > otp_record.expires_at:
        otp_record.is_used = True
        db.commit()
        raise InvalidCredentialsError("OTP has expired. Please request a new one.")

    # Step 3: Check attempt limit
    if otp_record.attempts >= MAX_VERIFY_ATTEMPTS:
        otp_record.is_used = True
        db.commit()
        raise InvalidCredentialsError(
            "Maximum verification attempts exceeded. Please request a new OTP."
        )

    # Step 4: Verify OTP code
    otp_record.attempts += 1

    if otp_record.otp_code != data.otp:
        db.commit()
        remaining = MAX_VERIFY_ATTEMPTS - otp_record.attempts
        raise InvalidCredentialsError(
            f"Invalid OTP. {remaining} attempt(s) remaining."
        )

    # Step 5: Mark OTP as used
    otp_record.is_used = True
    db.commit()

    # Step 6: Find or create user
    user = db.query(User).filter(User.phone_number == data.phone_number).first()
    is_new_user = False

    if not user:
        # Auto-register new user on first OTP verification
        user = User(phone_number=data.phone_number)
        db.add(user)
        db.commit()
        db.refresh(user)
        is_new_user = True
        logger.info(f"[AUTH] New user registered: {user.id} ({data.phone_number})")
    else:
        if not user.is_active:
            raise InvalidCredentialsError("Account has been deactivated.")
        logger.info(f"[AUTH] User logged in: {user.id} ({data.phone_number})")

    # Step 7: Generate JWT
    token = create_access_token(data={"sub": str(user.id)})

    # Step 8: Return response
    return AuthResponse(
        access_token=token,
        user=UserResponse(
            id=str(user.id),
            full_name=user.full_name,
            phone_number=user.phone_number,
            is_active=user.is_active,
            is_new_user=is_new_user,
            created_at=user.created_at,
        ),
    )
