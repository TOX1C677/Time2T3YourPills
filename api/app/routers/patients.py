from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import require_patient
from app.models import PatientProfile, User
from app.schemas import InviteCodeOut, PatientProfileOut, PatientProfileUpdate

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
