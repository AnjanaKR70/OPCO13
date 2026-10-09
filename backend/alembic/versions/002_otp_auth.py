"""Switch to OTP-based auth: add otps table, drop password_hash from users

Revision ID: 002_otp_auth
Revises: 001_initial
Create Date: 2026-07-18

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


# revision identifiers, used by Alembic.
revision: str = "002_otp_auth"
down_revision: Union[str, None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Create OTPs table ────────────────────────────────────
    op.create_table(
        "otps",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("phone_number", sa.String(15), nullable=False),
        sa.Column("otp_code", sa.String(6), nullable=False),
        sa.Column("is_used", sa.Boolean(), default=False),
        sa.Column("attempts", sa.Integer(), default=0),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_otps_phone_number", "otps", ["phone_number"])
    op.create_index("ix_otps_created_at", "otps", ["created_at"])

    # ── Update users table: drop password_hash, make full_name nullable ──
    op.drop_column("users", "password_hash")
    op.alter_column("users", "full_name", nullable=True)


def downgrade() -> None:
    # Restore password_hash column
    op.add_column(
        "users",
        sa.Column("password_hash", sa.String(255), nullable=True),
    )
    op.alter_column("users", "full_name", nullable=False)

    # Drop OTPs table
    op.drop_index("ix_otps_created_at", table_name="otps")
    op.drop_index("ix_otps_phone_number", table_name="otps")
    op.drop_table("otps")
