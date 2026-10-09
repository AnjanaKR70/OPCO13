"""Initial schema — users, permissions, scan_history, cyber_contacts

Revision ID: 001_initial
Revises: None
Create Date: 2026-07-18

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


# revision identifiers, used by Alembic.
revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Users table ──────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("full_name", sa.String(100), nullable=False),
        sa.Column("phone_number", sa.String(15), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_users_phone_number", "users", ["phone_number"], unique=True)

    # ── Permissions table ────────────────────────────────────
    op.create_table(
        "permissions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("storage_permission", sa.Boolean(), default=False),
        sa.Column("sms_permission", sa.Boolean(), default=False),
        sa.Column("phone_permission", sa.Boolean(), default=False),
        sa.Column("gmail_permission", sa.Boolean(), default=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_permissions_user_id", "permissions", ["user_id"], unique=True)

    # ── Scan History table ───────────────────────────────────
    op.create_table(
        "scan_history",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_size", sa.Integer(), nullable=False),
        sa.Column("mime_type", sa.String(100), nullable=False),
        sa.Column("verdict", sa.String(50), nullable=False),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("risk_level", sa.String(20), nullable=False),
        sa.Column("scanned_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_scan_history_user_id", "scan_history", ["user_id"])
    op.create_index("ix_scan_history_scanned_at", "scan_history", ["scanned_at"])

    # ── Cyber Contacts table ─────────────────────────────────
    op.create_table(
        "cyber_contacts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("designation", sa.String(150), nullable=True),
        sa.Column("phone", sa.String(15), nullable=True),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("state", sa.String(100), nullable=True),
        sa.Column("website", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean(), default=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── Seed Cyber Contacts ──────────────────────────────────
    # Pre-populate with Indian cyber cell contacts
    op.execute("""
        INSERT INTO cyber_contacts (id, name, designation, phone, email, address, state, website, is_active)
        VALUES
        (gen_random_uuid(), 'National Cyber Crime Reporting Portal', 'Central Helpline', '1930', 'cybercrime@nic.in', 'Ministry of Home Affairs, New Delhi', 'All India', 'https://cybercrime.gov.in', true),
        (gen_random_uuid(), 'Kerala Cyber Police', 'State Cyber Cell', '0471-2721547', 'cyberdome@keralapolice.gov.in', 'Police Headquarters, Thiruvananthapuram', 'Kerala', 'https://keralapolice.gov.in', true),
        (gen_random_uuid(), 'Indian Computer Emergency Response Team', 'CERT-In', '1800-11-4949', 'incident@cert-in.org.in', 'Electronics Niketan, CGO Complex, New Delhi', 'All India', 'https://cert-in.org.in', true)
    """)


def downgrade() -> None:
    op.drop_table("cyber_contacts")
    op.drop_table("scan_history")
    op.drop_table("permissions")
    op.drop_table("users")
