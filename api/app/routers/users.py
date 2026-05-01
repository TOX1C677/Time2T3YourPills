from typing import Annotated

from fastapi import APIRouter, Depends, status
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
    if body.display_name is not None:
        user.display_name = body.display_name.strip()
    if body.ui_bold_fonts is not None or body.display_name is not None:
        db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(
    user: Annotated[User, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
) -> None:
    """Безвозвратное удаление аккаунта.

    Связанные строки (профиль пациента, привязки опекун-пациент, препараты, события приёмов,
    пропуски) удаляются каскадом по внешним ключам в БД.
    """
    db.delete(user)
    db.commit()
