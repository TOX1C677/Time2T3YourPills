from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_patient
from app.models import IntakeEvent
from app.models import Medication as MedRow
from app.models import PatientProfile, User
from app.schemas import (
    IntakeEventCreate,
    IntakeEventOut,
    InviteCodeOut,
    MedicationOut,
    MedicationUpsert,
    PatientProfileOut,
    PatientProfileUpdate,
)

router = APIRouter(prefix="/patients", tags=["patients"])


@router.get("/me/invite-code", response_model=InviteCodeOut)
def get_invite_code(
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
) -> InviteCodeOut:
    profile = db.get(PatientProfile, user.id)
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Patient profile missing")
    return InviteCodeOut(token=profile.link_token)


@router.get("/me/profile", response_model=PatientProfileOut)
def get_my_profile(
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
) -> PatientProfile:
    profile = db.get(PatientProfile, user.id)
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Patient profile missing")
    return profile


@router.patch("/me/profile", response_model=PatientProfileOut)
def patch_my_profile(
    body: PatientProfileUpdate,
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
) -> PatientProfile:
    profile = db.get(PatientProfile, user.id)
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Patient profile missing")
    if body.first_name is not None:
        profile.first_name = body.first_name
    if body.middle_name is not None:
        profile.middle_name = body.middle_name
    if body.timezone is not None:
        profile.timezone = body.timezone
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile


@router.get("/me/medications", response_model=list[MedicationOut])
def list_my_medications(
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
) -> list[MedRow]:
    rows = db.scalars(
        select(MedRow)
        .where(MedRow.patient_user_id == user.id, MedRow.deleted_at.is_(None))
        .order_by(MedRow.created_at)
    ).all()
    return list(rows)


@router.put("/me/medications/{medication_id}", response_model=MedicationOut)
def upsert_my_medication(
    medication_id: UUID,
    body: MedicationUpsert,
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
) -> MedRow:
    row = db.get(MedRow, medication_id)
    if row is None:
        row = MedRow(
            id=medication_id,
            patient_user_id=user.id,
            name=body.name,
            dosage=body.dosage,
            reminder_mode=body.reminder_mode,
            interval_minutes=body.interval_minutes,
            slot_times=body.slot_times,
            deleted_at=None,
        )
        db.add(row)
    else:
        if row.patient_user_id != user.id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your medication")
        row.name = body.name
        row.dosage = body.dosage
        row.reminder_mode = body.reminder_mode
        row.interval_minutes = body.interval_minutes
        row.slot_times = body.slot_times
        row.deleted_at = None
    db.commit()
    db.refresh(row)
    return row


@router.delete("/me/medications/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_medication(
    medication_id: UUID,
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
) -> None:
    row = db.get(MedRow, medication_id)
    if row is None or row.patient_user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Medication not found")
    if row.deleted_at is not None:
        return None
    row.deleted_at = datetime.now(UTC)
    db.add(row)
    db.commit()
    return None


@router.post("/me/intake-events", response_model=IntakeEventOut, status_code=status.HTTP_201_CREATED)
def create_my_intake_event(
    body: IntakeEventCreate,
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
) -> IntakeEvent:
    med_id = body.medication_id
    if med_id is not None:
        med = db.get(MedRow, med_id)
        if med is None or med.patient_user_id != user.id or med.deleted_at is not None:
            med_id = None
    row = IntakeEvent(
        patient_user_id=user.id,
        medication_id=med_id,
        medication_name_snapshot=body.medication_name_snapshot,
        dosage_snapshot=body.dosage_snapshot,
        scheduled_at=body.scheduled_at,
        recorded_at=body.recorded_at,
        source=body.source,
        status=body.status,
        snooze_until=body.snooze_until,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


@router.get("/me/intake-events", response_model=list[IntakeEventOut])
def list_my_intake_events(
    user: Annotated[User, Depends(require_patient)],
    db: Session = Depends(get_db),
    from_: datetime | None = Query(None, alias="from"),
    to_: datetime | None = Query(None, alias="to"),
) -> list[IntakeEvent]:
    stmt = select(IntakeEvent).where(IntakeEvent.patient_user_id == user.id).order_by(IntakeEvent.recorded_at.desc())
    if from_ is not None:
        stmt = stmt.where(IntakeEvent.recorded_at >= from_)
    if to_ is not None:
        stmt = stmt.where(IntakeEvent.recorded_at <= to_)
    rows = db.scalars(stmt).all()
    return list(rows)
