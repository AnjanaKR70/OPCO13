"""
Cyber contact service — retrieves cyber cell contact information from PostgreSQL.
"""

from sqlalchemy.orm import Session

from app.models.cyber_contact import CyberContact
from app.schemas.cyber_contact import CyberContactResponse, CyberContactListResponse
from app.utils.logger import logger


def get_all_contacts(db: Session) -> CyberContactListResponse:
    """
    Retrieve all active cyber cell contacts.

    Returns:
        List of active contacts with total count.
    """
    contacts = (
        db.query(CyberContact)
        .filter(CyberContact.is_active == True)  # noqa: E712
        .order_by(CyberContact.state, CyberContact.name)
        .all()
    )

    contact_list = [
        CyberContactResponse(
            id=str(contact.id),
            name=contact.name,
            designation=contact.designation,
            phone=contact.phone,
            email=contact.email,
            address=contact.address,
            state=contact.state,
            website=contact.website,
        )
        for contact in contacts
    ]

    logger.info(f"Cyber contacts retrieved: {len(contact_list)} active contacts")

    return CyberContactListResponse(
        contacts=contact_list,
        total=len(contact_list),
    )
