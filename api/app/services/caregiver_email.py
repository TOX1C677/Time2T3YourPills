"""Письма опекунам о пропусках (опционально через SMTP)."""

from __future__ import annotations

import logging
import smtplib
import ssl
from datetime import UTC, datetime
from email.message import EmailMessage
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import CaregiverPatientLink, MissedIntakeAlert
from app.models import Medication as MedRow
from app.models import PatientProfile, User

logger = logging.getLogger(__name__)


def _smtp_send(msg: EmailMessage, recipients: list[str]) -> None:
    host = settings.smtp_host.strip()
    port = int(settings.smtp_port)
    user = (settings.smtp_user or "").strip()
    password = (settings.smtp_password or "").strip()
    use_tls = settings.smtp_use_tls

    if port == 465:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(host, port, timeout=20, context=context) as smtp:
            if user:
                smtp.login(user, password)
            smtp.send_message(msg, to_addrs=recipients)
        return

    with smtplib.SMTP(host, port, timeout=20) as smtp:
        if use_tls:
            context = ssl.create_default_context()
            smtp.starttls(context=context)
        if user:
            smtp.login(user, password)
        smtp.send_message(msg, to_addrs=recipients)


def send_missed_alert_emails(db: Session, alert_ids: list[UUID]) -> int:
    """Отправляет письма по новым алертам. Возвращает число успешно отправленных писем (по одному на алерт)."""
    if not alert_ids or not settings.smtp_host.strip():
        return 0

    from_addr = (settings.smtp_from_email or settings.smtp_user or "").strip()
    if not from_addr:
        logger.warning("SMTP: не задан smtp_from_email / smtp_user — пропуск отправки")
        return 0

    delivered = 0
    now = datetime.now(UTC)

    for aid in alert_ids:
        alert = db.get(MissedIntakeAlert, aid)
        if alert is None or alert.notified_caregiver_at is not None:
            continue

        patient = db.get(User, alert.patient_user_id)
        med = db.get(MedRow, alert.medication_id)
        if patient is None or med is None:
            continue

        prof = db.get(PatientProfile, alert.patient_user_id)
        pname = (patient.display_name or "").strip()
        if not pname and prof is not None:
            parts = [prof.first_name, prof.middle_name]
            pname = " ".join(p for p in parts if p).strip() or patient.email

        caregivers = db.scalars(
            select(User).join(
                CaregiverPatientLink,
                CaregiverPatientLink.caregiver_user_id == User.id,
            ).where(CaregiverPatientLink.patient_user_id == alert.patient_user_id)
        ).all()

        to_addrs = [c.email for c in caregivers if c.email]
        if not to_addrs:
            continue

        due_s = alert.due_at.astimezone(UTC).strftime("%Y-%m-%d %H:%M UTC")
        subject = f"Time2T3: пропуск приёма — {med.name}"
        body = (
            f"Пациент: {pname}\n"
            f"Препарат: {med.name}\n"
            f"Ожидался приём (по плану): {due_s}\n\n"
            "Проверьте, всё ли в порядке, и при необходимости свяжитесь с пациентом.\n"
            "Это автоматическое сообщение приложения Time2T3 Your Pills."
        )

        msg = EmailMessage()
        msg["Subject"] = subject
        msg["From"] = from_addr
        msg["To"] = ", ".join(to_addrs)
        msg.set_content(body)

        try:
            _smtp_send(msg, to_addrs)
        except (OSError, smtplib.SMTPException) as e:
            logger.warning("SMTP miss alert %s: %s", aid, e)
            continue

        alert.notified_caregiver_at = now
        delivered += 1

    if delivered:
        db.commit()
    return delivered
