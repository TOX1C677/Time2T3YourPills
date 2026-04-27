from __future__ import annotations

import enum
import secrets
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.types import JSON

from app.database import Base


def _json_type():
    """JSON на SQLite/Postgres."""
    return JSON().with_variant(JSONB(), "postgresql")


class UserRole(str, enum.Enum):
    patient = "patient"
    caregiver = "caregiver"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(32), nullable=False)
    display_name: Mapped[str] = mapped_column(String(200), default="")
    email_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    patient_profile: Mapped[PatientProfile | None] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan"
    )


class PatientProfile(Base):
    __tablename__ = "patient_profiles"

    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    first_name: Mapped[str] = mapped_column(String(200), default="")
    middle_name: Mapped[str] = mapped_column(String(200), default="")
    timezone: Mapped[str] = mapped_column(String(64), default="Europe/Moscow")
    link_token: Mapped[str] = mapped_column(String(64), nullable=False, unique=True, index=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped[User] = relationship(back_populates="patient_profile")


class CaregiverPatientLink(Base):
    __tablename__ = "caregiver_patient_links"
    __table_args__ = (UniqueConstraint("caregiver_user_id", "patient_user_id", name="uq_caregiver_patient"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    caregiver_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    patient_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Medication(Base):
    __tablename__ = "medications"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    patient_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(500), nullable=False)
    dosage: Mapped[str] = mapped_column(String(200), default="")
    reminder_mode: Mapped[str] = mapped_column(String(32), nullable=False)
    interval_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    slot_times: Mapped[list | None] = mapped_column(_json_type(), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class IntakeEvent(Base):
    __tablename__ = "intake_events"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    patient_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    medication_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("medications.id", ondelete="SET NULL"), nullable=True, index=True
    )
    medication_name_snapshot: Mapped[str] = mapped_column(String(500), default="")
    dosage_snapshot: Mapped[str] = mapped_column(String(200), default="")
    scheduled_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source: Mapped[str] = mapped_column(String(32), default="patient_app", nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False)
    snooze_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class MissedIntakeAlert(Base):
    __tablename__ = "missed_intake_alerts"
    __table_args__ = (
        UniqueConstraint("patient_user_id", "medication_id", "due_at", name="uq_missed_patient_med_due"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    patient_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    medication_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("medications.id", ondelete="CASCADE"), index=True)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    detected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    notified_caregiver_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


def generate_link_token() -> str:
    return secrets.token_urlsafe(32)
