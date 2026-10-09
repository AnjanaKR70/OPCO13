"""
User permissions routes — create, read, update device permissions.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.dependencies import get_db, get_current_user
from app.models.user import User
from app.schemas.permission import PermissionCreate, PermissionUpdate
from app.services import permission_service
from app.response import success_response

router = APIRouter(prefix="/user", tags=["User Permissions"])


@router.post("/permissions", summary="Set initial permissions", status_code=201)
def create_permissions(
    data: PermissionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Create the initial permissions record for the authenticated user.

    This should be called once after signup when the user grants/denies
    device permissions (storage, SMS, phone, Gmail).
    """
    result = permission_service.create_permissions(db, current_user.id, data)
    return success_response(
        message="Permissions saved successfully",
        data=result.model_dump(),
    )


@router.get("/permissions", summary="Get current permissions")
def get_permissions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieve the current permission settings for the authenticated user.
    """
    result = permission_service.get_permissions(db, current_user.id)
    return success_response(
        message="Permissions retrieved",
        data=result.model_dump(),
    )


@router.put("/permissions", summary="Update permissions")
def update_permissions(
    data: PermissionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Update one or more permission settings for the authenticated user.

    Only the fields included in the request body will be updated.
    Omitted fields remain unchanged.
    """
    result = permission_service.update_permissions(db, current_user.id, data)
    return success_response(
        message="Permissions updated successfully",
        data=result.model_dump(),
    )
