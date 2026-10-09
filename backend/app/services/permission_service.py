"""
Permission service — CRUD for user device permissions.
"""

import uuid

from sqlalchemy.orm import Session

from app.models.permission import Permission
from app.schemas.permission import PermissionCreate, PermissionUpdate, PermissionResponse
from app.exceptions import PermissionNotFoundError, PermissionAlreadyExistsError
from app.utils.logger import logger


def create_permissions(
    db: Session, user_id: uuid.UUID, data: PermissionCreate
) -> PermissionResponse:
    """Create initial permissions record for a user."""
    existing = db.query(Permission).filter(Permission.user_id == user_id).first()
    if existing:
        raise PermissionAlreadyExistsError()

    permission = Permission(
        user_id=user_id,
        storage_permission=data.storage_permission,
        sms_permission=data.sms_permission,
        phone_permission=data.phone_permission,
        gmail_permission=data.gmail_permission,
    )
    db.add(permission)
    db.commit()
    db.refresh(permission)

    logger.info(f"Permissions created for user: {user_id}")

    return PermissionResponse(
        id=str(permission.id),
        user_id=str(permission.user_id),
        storage_permission=permission.storage_permission,
        sms_permission=permission.sms_permission,
        phone_permission=permission.phone_permission,
        gmail_permission=permission.gmail_permission,
        updated_at=permission.updated_at,
    )


def get_permissions(db: Session, user_id: uuid.UUID) -> PermissionResponse:
    """Get permissions for a user."""
    permission = db.query(Permission).filter(Permission.user_id == user_id).first()
    if not permission:
        raise PermissionNotFoundError()

    return PermissionResponse(
        id=str(permission.id),
        user_id=str(permission.user_id),
        storage_permission=permission.storage_permission,
        sms_permission=permission.sms_permission,
        phone_permission=permission.phone_permission,
        gmail_permission=permission.gmail_permission,
        updated_at=permission.updated_at,
    )


def update_permissions(
    db: Session, user_id: uuid.UUID, data: PermissionUpdate
) -> PermissionResponse:
    """Update permissions for a user. Only updates fields that are provided."""
    permission = db.query(Permission).filter(Permission.user_id == user_id).first()
    if not permission:
        raise PermissionNotFoundError()

    # Only update fields that were explicitly provided
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(permission, field, value)

    db.commit()
    db.refresh(permission)

    logger.info(f"Permissions updated for user: {user_id}")

    return PermissionResponse(
        id=str(permission.id),
        user_id=str(permission.user_id),
        storage_permission=permission.storage_permission,
        sms_permission=permission.sms_permission,
        phone_permission=permission.phone_permission,
        gmail_permission=permission.gmail_permission,
        updated_at=permission.updated_at,
    )
