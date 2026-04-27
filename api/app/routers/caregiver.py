from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_caregiver
from app.models import CaregiverPatientLink, PatientProfile, User, UserRole
from app.schemas import CaregiverPatientOut, LinkPatientRequest

router = APIRouter(prefix="/caregiver", tags=["caregiver"])


@router.post("/link-patient")
def link_patient(
    body: LinkPatientRequest,
    caregiver: Annotated[User, Depends(require_caregiver)],
    db: Session = Depends(get_db),
) -> dict[str, str]:
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
                middle_name=profile.middle_name,
            )
        )
    return out
