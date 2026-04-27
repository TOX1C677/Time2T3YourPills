"""Обнаружение пропущенных приёмов по интервальным лекарствам (v1).

Режим «по расписанию» (slot_times) пока не сканируется — см. план §8.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import IntakeEvent, Medication as MedRow, MissedIntakeAlert

_TOLERANCE = timedelta(seconds=30)
_MAX_INTERVAL_STEPS = 200


def _as_utc(dt: datetime) -> datetime:
    """SQLite может отдавать naive datetime — приводим к UTC."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def run_missed_intake_scan(db: Session, grace_minutes: int) -> int:
    """Создаёт записи [MissedIntakeAlert] для пропущенных окон. Возвращает число новых строк."""
    now = datetime.now(UTC)
    grace = timedelta(minutes=max(0, grace_minutes))
    meds = db.scalars(
        select(MedRow).where(
            MedRow.deleted_at.is_(None),
            MedRow.reminder_mode == "interval",
            MedRow.interval_minutes.is_not(None),
            MedRow.interval_minutes > 0,
        )
    ).all()

    created = 0
    for med in meds:
        interval = timedelta(minutes=int(med.interval_minutes or 0))
        if interval.total_seconds() <= 0:
            continue

        last = db.scalars(
            select(IntakeEvent)
            .where(
                IntakeEvent.patient_user_id == med.patient_user_id,
                IntakeEvent.medication_id == med.id,
                IntakeEvent.status == "confirmed",
            )
            .order_by(IntakeEvent.scheduled_at.desc())
            .limit(1)
        ).first()
        if last is None:
            continue

        next_due = _as_utc(last.scheduled_at) + interval
        steps = 0
        while steps < _MAX_INTERVAL_STEPS:
            steps += 1
            if next_due + grace > now:
                break

            caught = db.scalars(
                select(IntakeEvent)
                .where(
                    IntakeEvent.patient_user_id == med.patient_user_id,
                    IntakeEvent.medication_id == med.id,
                    IntakeEvent.status == "confirmed",
                    IntakeEvent.scheduled_at >= next_due - _TOLERANCE,
                )
                .order_by(IntakeEvent.scheduled_at.asc())
                .limit(1)
            ).first()
            if caught is not None:
                next_due = _as_utc(caught.scheduled_at) + interval
                continue

            due_norm = next_due.replace(microsecond=0)
            exists = db.scalar(
                select(MissedIntakeAlert.id).where(
                    MissedIntakeAlert.patient_user_id == med.patient_user_id,
                    MissedIntakeAlert.medication_id == med.id,
                    MissedIntakeAlert.due_at == due_norm,
                )
            )
            if exists is None:
                db.add(
                    MissedIntakeAlert(
                        patient_user_id=med.patient_user_id,
                        medication_id=med.id,
                        due_at=due_norm,
                        detected_at=now,
                    )
                )
                created += 1

            next_due = next_due + interval

    db.commit()
    return created
