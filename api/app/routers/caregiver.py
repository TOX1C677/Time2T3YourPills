from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.deps import require_caregiver
from app.models import CaregiverPatientLink, IntakeEvent
from app.models import Medication as MedRow
from app.models import MissedIntakeAlert, PatientProfile, User, UserRole
from app.rate_limit import enforce_hourly_limit
from app.schemas import (
    CaregiverPatientOut,
    IntakeEventOut,
    LinkPatientRequest,
    MedicationOut,
    MedicationUpsert,
    MissedIntakeAlertOut,
)

router = APIRouter(prefix="/caregiver", tags=["caregiver"])


def _assert_caregiver_linked(db: Session, caregiver_id: UUID, patient_user_id: UUID) -> None:
    ok = db.scalar(
        select(CaregiverPatientLink.id).where(
            CaregiverPatientLink.caregiver_user_id == caregiver_id,
            CaregiverPatientLink.patient_user_id == patient_user_id,
        )
    )
    if ok is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Patient not linked to this caregiver")


@router.post("/link-patient")
def link_patient(
    body: LinkPatientRequest,
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
) -> dict[str, str]:
    enforce_hourly_limit(
        f"caregiver_link:{caregiver.id}",
        settings.caregiver_link_attempts_per_hour,
        "Слишком много попыток привязки пациента, подождите час",
    )
    token = body.token.strip()
    profile = db.scalar(select(PatientProfile).where(PatientProfile.link_token == token))
    if profile is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Invalid code")
    patient_id: UUID = profile.user_id
    patient = db.get(User, patient_id)
    if patient is None or patient.role != UserRole.patient.value:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Invalid patient account")
    if patient_id == caregiver.id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cannot link your own account")

    existing = db.scalar(
        select(CaregiverPatientLink.id).where(
            CaregiverPatientLink.caregiver_user_id == caregiver.id,
            CaregiverPatientLink.patient_user_id == patient_id,
        )
    )
    if existing:
        return {"status": "already_linked", "patient_user_id": str(patient_id)}

    db.add(
        CaregiverPatientLink(
            caregiver_user_id=caregiver.id,
            patient_user_id=patient_id,
        )
    )
    db.commit()
    return {"status": "linked", "patient_user_id": str(patient_id)}


@router.get("/patients", response_model=list[CaregiverPatientOut])
def list_patients(
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
) -> list[CaregiverPatientOut]:
    rows = db.execute(
        select(PatientProfile, User)
        .join(User, User.id == PatientProfile.user_id)
        .join(
            CaregiverPatientLink,
            (CaregiverPatientLink.patient_user_id == PatientProfile.user_id)
            & (CaregiverPatientLink.caregiver_user_id == caregiver.id),
        )
    ).all()
    out: list[CaregiverPatientOut] = []
    for profile, user in rows:
        out.append(
            CaregiverPatientOut(
                patient_user_id=user.id,
                display_name=user.display_name,
                first_name=profile.first_name,
                last_name=profile.last_name,
                middle_name=profile.middle_name,
            )
        )
    return out


@router.get("/alerts", response_model=list[MissedIntakeAlertOut])
def list_missed_intake_alerts(
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
) -> list[MissedIntakeAlertOut]:
    rows = db.execute(
        select(MissedIntakeAlert, User, MedRow, PatientProfile)
        .join(User, User.id == MissedIntakeAlert.patient_user_id)
        .outerjoin(PatientProfile, PatientProfile.user_id == User.id)
        .join(MedRow, MedRow.id == MissedIntakeAlert.medication_id)
        .join(
            CaregiverPatientLink,
            (CaregiverPatientLink.patient_user_id == MissedIntakeAlert.patient_user_id)
            & (CaregiverPatientLink.caregiver_user_id == caregiver.id),
        )
        .order_by(MissedIntakeAlert.detected_at.desc())
    ).all()
    out: list[MissedIntakeAlertOut] = []
    for alert, patient_user, med, prof in rows:
        name = (patient_user.display_name or "").strip()
        if not name and prof is not None:
            parts = [prof.first_name, prof.last_name, prof.middle_name]
            name = " ".join(p for p in parts if p).strip()
        out.append(
            MissedIntakeAlertOut(
                id=alert.id,
                patient_user_id=alert.patient_user_id,
                patient_display_name=name or str(alert.patient_user_id),
                medication_id=alert.medication_id,
                medication_name=med.name,
                due_at=alert.due_at,
                detected_at=alert.detected_at,
            )
        )
    return out


@router.get("/patients/{patient_user_id}/medications", response_model=list[MedicationOut])
def list_patient_medications(
    patient_user_id: UUID,
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
) -> list[MedRow]:
    _assert_caregiver_linked(db, caregiver.id, patient_user_id)
    rows = db.scalars(
        select(MedRow)
        .where(MedRow.patient_user_id == patient_user_id, MedRow.deleted_at.is_(None))
        .order_by(MedRow.created_at)
    ).all()
    return list(rows)


@router.put("/patients/{patient_user_id}/medications/{medication_id}", response_model=MedicationOut)
def upsert_patient_medication(
    patient_user_id: UUID,
    medication_id: UUID,
    body: MedicationUpsert,
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
) -> MedRow:
    _assert_caregiver_linked(db, caregiver.id, patient_user_id)
    row = db.get(MedRow, medication_id)
    if row is None:
        row = MedRow(
            id=medication_id,
            patient_user_id=patient_user_id,
            name=body.name,
            dosage=body.dosage,
            reminder_mode=body.reminder_mode,
            interval_minutes=body.interval_minutes,
            slot_times=body.slot_times,
            deleted_at=None,
        )
        db.add(row)
    else:
        if row.patient_user_id != patient_user_id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Medication belongs to another patient")
        row.name = body.name
        row.dosage = body.dosage
        row.reminder_mode = body.reminder_mode
        row.interval_minutes = body.interval_minutes
        row.slot_times = body.slot_times
        row.deleted_at = None
    db.commit()
    db.refresh(row)
    return row


@router.delete(
    "/patients/{patient_user_id}/medications/{medication_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_patient_medication(
    patient_user_id: UUID,
    medication_id: UUID,
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
) -> None:
    _assert_caregiver_linked(db, caregiver.id, patient_user_id)
    row = db.get(MedRow, medication_id)
    if row is None or row.patient_user_id != patient_user_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Medication not found")
    if row.deleted_at is not None:
        return None
    row.deleted_at = datetime.now(UTC)
    db.add(row)
    db.commit()
    return None


@router.get("/patients/{patient_user_id}/intake-events", response_model=list[IntakeEventOut])
def list_patient_intake_events(
    patient_user_id: UUID,
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
    from_: datetime | None = Query(None, alias="from"),
    to_: datetime | None = Query(None, alias="to"),
) -> list[IntakeEvent]:
    _assert_caregiver_linked(db, caregiver.id, patient_user_id)
    stmt = (
        select(IntakeEvent)
        .where(IntakeEvent.patient_user_id == patient_user_id)
        .order_by(IntakeEvent.recorded_at.desc())
    )
    if from_ is not None:
        stmt = stmt.where(IntakeEvent.recorded_at >= from_)
    if to_ is not None:
        stmt = stmt.where(IntakeEvent.recorded_at <= to_)
    rows = db.scalars(stmt).all()
    return list(rows)
