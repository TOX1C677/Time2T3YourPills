from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.services.caregiver_email import retry_pending_missed_alert_emails, send_missed_alert_emails
from app.services.missed_intake_scan import run_missed_intake_scan

router = APIRouter(prefix="/system", tags=["system"])


@router.post("/missed-intake-scan")
def missed_intake_scan(
    db: Session = Depends(get_db),
    x_worker_key: str | None = Header(default=None, alias="X-Worker-Key"),
) -> dict[str, int]:
    """Периодический вызов из cron/systemd; защита общим секретом."""
    if not settings.worker_api_key.strip():
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "WORKER_API_KEY не задан в окружении",
        )
    if not x_worker_key or x_worker_key != settings.worker_api_key:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный ключ worker")
    created = run_missed_intake_scan(db, settings.missed_intake_grace_minutes)
    emailed_new = send_missed_alert_emails(db, [a.id for a in created])
    emailed_retry = retry_pending_missed_alert_emails(db, limit=50)
    return {
        "new_alerts": len(created),
        "emails_sent": emailed_new + emailed_retry,
    }
