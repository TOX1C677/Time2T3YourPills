"""add last_name to patient_profiles

Revision ID: c4f8a1b2d3e5
Revises: 5d8e9dac9fa6
Create Date: 2026-04-24

"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "c4f8a1b2d3e5"
down_revision = "5d8e9dac9fa6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "patient_profiles",
        sa.Column("last_name", sa.String(length=200), nullable=False, server_default=""),
    )


def downgrade() -> None:
    op.drop_column("patient_profiles", "last_name")
