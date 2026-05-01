from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    display_name: str = Field(default="", max_length=200)
    role: str = Field(pattern="^(patient|caregiver)$")


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    role: str
    email: str


class UserMeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: EmailStr
    role: str
    display_name: str
    ui_bold_fonts: bool


class UserSelfPatch(BaseModel):
    ui_bold_fonts: bool | None = None
    display_name: str | None = Field(default=None, max_length=200)


class PatientProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    first_name: str
    last_name: str
    middle_name: str
    timezone: str
    updated_at: datetime | None = None


class PatientProfileUpdate(BaseModel):
    first_name: str | None = Field(default=None, max_length=200)
    last_name: str | None = Field(default=None, max_length=200)
    middle_name: str | None = Field(default=None, max_length=200)
    timezone: str | None = Field(default=None, max_length=64)


class InviteCodeOut(BaseModel):
    token: str


class LinkPatientRequest(BaseModel):
    token: str = Field(min_length=8, max_length=128)


class CaregiverPatientOut(BaseModel):
    patient_user_id: UUID
    display_name: str
    first_name: str
    last_name: str
    middle_name: str


class MedicationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    patient_user_id: UUID
    name: str
    dosage: str
    reminder_mode: str
    interval_minutes: int | None = None
    slot_times: list[str] | None = None
    first_intake_time: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


class IntakeEventCreate(BaseModel):
    medication_id: UUID | None = None
    scheduled_at: datetime
    recorded_at: datetime
    status: str = Field(default="confirmed", pattern="^(confirmed|missed|snoozed)$")
    medication_name_snapshot: str = Field(default="", max_length=500)
    dosage_snapshot: str = Field(default="", max_length=200)
    source: str = Field(default="patient_app", pattern="^(patient_app|caregiver_override|system)$")
    snooze_until: datetime | None = None


class IntakeEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    patient_user_id: UUID
    medication_id: UUID | None
    medication_name_snapshot: str
    dosage_snapshot: str
    scheduled_at: datetime
    recorded_at: datetime
    source: str
    status: str
    snooze_until: datetime | None = None


class ReminderEscalationItem(BaseModel):
    """Один просроченный приём для фиксации алерта опекунам (после игнорирования напоминаний на телефоне)."""

    medication_id: UUID
    due_at: datetime


class ReminderEscalationRequest(BaseModel):
    items: list[ReminderEscalationItem] = Field(..., min_length=1, max_length=32)


class ReminderEscalationResponse(BaseModel):
    new_alerts: int
    emails_sent: int


class MedicationUpsert(BaseModel):
    """Тело PUT: создание или полная замена полей (клиент задаёт id в path)."""

    name: str = Field(..., max_length=500)
    dosage: str = Field(default="", max_length=200)
    reminder_mode: str = Field(pattern="^(interval|schedule)$")
    interval_minutes: int | None = None
    slot_times: list[str] | None = None
    first_intake_time: str | None = Field(default=None, max_length=8)


class MissedIntakeAlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    patient_user_id: UUID
    patient_display_name: str
    medication_id: UUID
    medication_name: str
    due_at: datetime
    detected_at: datetime
