from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import UserMeOut, UserSelfPatch

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserMeOut)
def read_me(user: Annotated[User, Depends(get_current_user)]) -> User:
    return user


@router.patch("/me", response_model=UserMeOut)
def patch_me(
    body: UserSelfPatch,
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    if body.ui_bold_fonts is not None:
        user.ui_bold_fonts = body.ui_bold_fonts
        db.add(user)
    db.commit()
    db.refresh(user)
    return user
