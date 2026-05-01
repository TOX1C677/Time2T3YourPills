"""medications.first_intake_time

Revision ID: f8e1a2b3c4d5
Revises: e7f9a0b1c2d3
Create Date: 2026-04-24

"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "f8e1a2b3c4d5"
down_revision = "e7f9a0b1c2d3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "medications",
        sa.Column("first_intake_time", sa.String(length=8), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("medications", "first_intake_time")
