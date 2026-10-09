"""
Cyber cell contacts route — public endpoint for contact information.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.dependencies import get_db
from app.services import cyber_contact_service
from app.response import success_response

router = APIRouter(prefix="/cybercell", tags=["Cyber Contacts"])


@router.get("/contacts", summary="Get cyber cell contact information")
def get_contacts(db: Session = Depends(get_db)):
    """
    Retrieve all active cyber cell contact information.

    This is a **public endpoint** — no authentication required.

    Contact data is stored in PostgreSQL so administrators can update it
    without requiring frontend code changes.

    **Returns:** Name, designation, phone, email, address, state, website
    """
    result = cyber_contact_service.get_all_contacts(db)
    return success_response(
        message="Cyber cell contacts retrieved",
        data=result.model_dump(),
    )
