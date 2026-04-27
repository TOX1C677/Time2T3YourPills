from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User, UserRole
from app.security import decode_token, parse_uuid_sub

security = HTTPBearer(auto_error=False)


def get_current_user(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")
    try:
        payload = decode_token(creds.credentials)
        if payload.get("type") != "access":
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token type")
        uid = parse_uuid_sub(payload)
    except JWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token") from None
    user = db.get(User, uid)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")
    return user


def require_patient(user: Annotated[User, Depends(get_current_user)]) -> User:
    if user.role != UserRole.patient.value:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Patient role required")
    return user


def require_caregiver(user: Annotated[User, Depends(get_current_user)]) -> User:
    if user.role != UserRole.caregiver.value:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Caregiver role required")
    return user
