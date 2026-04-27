"""users.ui_bold_fonts

Revision ID: e7f9a0b1c2d3
Revises: c4f8a1b2d3e5
Create Date: 2026-04-24

"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "e7f9a0b1c2d3"
down_revision = "c4f8a1b2d3e5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "ui_bold_fonts",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "ui_bold_fonts")
