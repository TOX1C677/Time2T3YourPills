from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import PatientProfile, RevokedRefreshJti, User, UserRole, generate_link_token
from app.schemas import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse
from app.security import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from app.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_bundle(user: User) -> TokenResponse:
    sub = str(user.id)
    access = create_access_token(sub, user.role)
    refresh = create_refresh_token(sub, user.role)
    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        expires_in=settings.jwt_access_minutes * 60,
        role=user.role,
        email=user.email,
    )


@router.post("/register", response_model=TokenResponse)
def register(body: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = body.email.lower().strip()
    exists = db.scalar(select(User.id).where(User.email == email))
    if exists:
        raise HTTPException(status.HTTP_409_CONFLICT, "Email already registered")
    user = User(
        email=email,
        password_hash=hash_password(body.password),
        role=body.role,
        display_name=body.display_name.strip() or email.split("@")[0],
    )
    db.add(user)
    db.flush()
    if body.role == UserRole.patient.value:
        first = (body.display_name.strip() or email.split("@")[0])[:200]
        profile = PatientProfile(
            user_id=user.id,
            first_name=first,
            last_name="",
            middle_name="",
            timezone="Europe/Moscow",
            link_token=generate_link_token(),
        )
        db.add(profile)
    db.commit()
    db.refresh(user)
    return _token_bundle(user)


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    email = body.email.lower().strip()
    user = db.scalar(select(User).where(User.email == email))
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid email or password")
    return _token_bundle(user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(body: RefreshRequest, db: Session = Depends(get_db)) -> None:
    """Инвалидация refresh по `jti` (клиент очищает хранилище после вызова)."""
    try:
        payload = decode_token(body.refresh_token)
    except Exception:
        return None
    if payload.get("type") != "refresh":
        return None
    jti = payload.get("jti")
    if not jti:
        return None
    sid = str(jti)
    if db.get(RevokedRefreshJti, sid) is None:
        db.add(RevokedRefreshJti(jti=sid))
        db.commit()
    return None


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(body: RefreshRequest, db: Session = Depends(get_db)) -> TokenResponse:
    try:
        payload = decode_token(body.refresh_token)
    except Exception:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token") from None
    if payload.get("type") != "refresh":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token type")
    jti = payload.get("jti")
    if jti:
        if db.get(RevokedRefreshJti, str(jti)) is not None:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Refresh token revoked")

    from uuid import UUID

    uid = UUID(str(payload["sub"]))
    user = db.get(User, uid)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")
    return _token_bundle(user)
