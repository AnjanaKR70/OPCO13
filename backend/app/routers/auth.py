"""
Authentication routes — OTP-based login/signup.

Flow:
1. POST /auth/send-otp   → Generate and "send" OTP (logged to console in dev)
2. POST /auth/verify-otp → Verify OTP, auto-create user if new, return JWT
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.dependencies import get_db
from app.schemas.auth import SendOTPRequest, VerifyOTPRequest
from app.services import auth_service
from app.response import success_response

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/send-otp", summary="Send OTP to an Indian phone number")
def send_otp(data: SendOTPRequest, db: Session = Depends(get_db)):
    """
    Generate and send a 6-digit OTP to the given phone number.

    **Rules:**
    - Only Indian numbers accepted (must start with **+91**)
    - OTP expires in **5 minutes**
    - Maximum **5 OTP requests per hour** per phone number
    - Previous unused OTPs for this number are automatically invalidated

    **Dev mode:** OTP is returned in the response (`dev_otp` field).
    In production, integrate your SMS gateway in the service layer.
    """
    result = auth_service.send_otp(db, data)
    return success_response(
        message=result.message,
        data=result.model_dump(),
    )


@router.post("/verify-otp", summary="Verify OTP and get JWT token")
def verify_otp(data: VerifyOTPRequest, db: Session = Depends(get_db)):
    """
    Verify the OTP and authenticate the user.

    **Behavior:**
    - If the phone number is **new**, a user account is automatically created (`is_new_user: true`)
    - If the phone number **exists**, the user is logged in
    - Maximum **5 verification attempts** per OTP
    - Returns a **JWT access token** (valid for 24 hours)

    **Use the token** in subsequent requests:
    ```
    Authorization: Bearer <token>
    ```
    """
    result = auth_service.verify_otp(db, data)
    return success_response(
        message="OTP verified successfully. You are now logged in.",
        data=result.model_dump(),
    )
