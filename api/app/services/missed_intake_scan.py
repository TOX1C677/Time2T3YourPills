"""Обнаружение пропущенных приёмов: интервал и расписание (slot_times) в таймзоне пациента."""

from __future__ import annotations

from datetime import UTC, datetime, time, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import IntakeEvent, Medication as MedRow, MissedIntakeAlert, PatientProfile

_TOLERANCE = timedelta(seconds=30)
_MAX_INTERVAL_STEPS = 200
_MAX_SCHEDULE_AGE = timedelta(days=7)


def _as_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC)


def _patient_tz(profile: PatientProfile | None):
    """ZoneInfo для IANA-имён; UTC без tzdata (Windows) - через datetime.UTC."""
    name = (profile.timezone if profile else "") or "UTC"
    name = name.strip() or "UTC"
    if name.upper() in ("UTC", "GMT", "ETC/UTC"):
        return UTC
    try:
        return ZoneInfo(name)
    except Exception:
        return UTC


def _parse_slot_hm(raw: str) -> time | None:
    s = (raw or "").strip()
    if not s:
        return None
    parts = s.replace(".", ":").split(":")
    try:
        h = int(parts[0])
        m = int(parts[1]) if len(parts) > 1 else 0
    except ValueError:
        return None
    if not (0 <= h <= 23 and 0 <= m <= 59):
        return None
    return time(h, m)


def _slot_times_list(med: MedRow) -> list[str]:
    st = med.slot_times
    if st is None:
        return []
    if isinstance(st, list):
        return [str(x) for x in st]
    return []


def _try_add_missed(
    db: Session,
    patient_user_id: UUID,
    medication_id: UUID,
    due_utc: datetime,
    now: datetime,
    created: list[MissedIntakeAlert],
) -> None:
    due_norm = _as_utc(due_utc).replace(microsecond=0)
    exists = db.scalar(
        select(MissedIntakeAlert.id).where(
            MissedIntakeAlert.patient_user_id == patient_user_id,
            MissedIntakeAlert.medication_id == medication_id,
            MissedIntakeAlert.due_at == due_norm,
        )
    )
    if exists is not None:
        return
    row = MissedIntakeAlert(
        patient_user_id=patient_user_id,
        medication_id=medication_id,
        due_at=due_norm,
        detected_at=now,
    )
    db.add(row)
    created.append(row)


def _scan_interval_med(
    db: Session,
    med: MedRow,
    now: datetime,
    grace: timedelta,
    created: list[MissedIntakeAlert],
) -> None:
    interval = timedelta(minutes=int(med.interval_minutes or 0))
    if interval.total_seconds() <= 0:
        return

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
        return

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

        _try_add_missed(db, med.patient_user_id, med.id, next_due, now, created)
        next_due = next_due + interval


def _scan_schedule_med(
    db: Session,
    med: MedRow,
    profile: PatientProfile | None,
    now: datetime,
    grace: timedelta,
    created: list[MissedIntakeAlert],
) -> None:
    slots_raw = _slot_times_list(med)
    times: list[time] = []
    for s in slots_raw:
        t = _parse_slot_hm(s)
        if t is not None:
            times.append(t)
    if not times:
        return

    tz = _patient_tz(profile)
    now_local = now.astimezone(tz)
    local_dates = {now_local.date(), (now_local - timedelta(days=1)).date()}

    for local_d in local_dates:
        for t in times:
            due_local = datetime.combine(local_d, t, tzinfo=tz)
            due_utc = due_local.astimezone(UTC)
            if due_utc + grace > now:
                continue
            if due_utc + grace < now - _MAX_SCHEDULE_AGE:
                continue

            caught = db.scalar(
                select(IntakeEvent.id).where(
                    IntakeEvent.patient_user_id == med.patient_user_id,
                    IntakeEvent.medication_id == med.id,
                    IntakeEvent.status == "confirmed",
                    IntakeEvent.scheduled_at >= due_utc - _TOLERANCE,
                    IntakeEvent.scheduled_at <= due_utc + timedelta(hours=4),
                )
            )
            if caught is not None:
                continue

            _try_add_missed(db, med.patient_user_id, med.id, due_utc, now, created)


def run_missed_intake_scan(
    db: Session,
    grace_minutes: int,
    *,
    at_time: datetime | None = None,
) -> list[MissedIntakeAlert]:
    """Создаёт алерты, делает commit. Возвращает список новых сущностей (с id после flush)."""
    now = at_time or datetime.now(UTC)
    now = _as_utc(now)
    grace = timedelta(minutes=max(0, grace_minutes))

    created: list[MissedIntakeAlert] = []

    interval_meds = db.scalars(
        select(MedRow).where(
            MedRow.deleted_at.is_(None),
            MedRow.reminder_mode == "interval",
            MedRow.interval_minutes.is_not(None),
            MedRow.interval_minutes > 0,
        )
    ).all()
    for med in interval_meds:
        _scan_interval_med(db, med, now, grace, created)

    schedule_meds = db.scalars(
        select(MedRow).where(
            MedRow.deleted_at.is_(None),
            MedRow.reminder_mode == "schedule",
        )
    ).all()
    for med in schedule_meds:
        prof = db.get(PatientProfile, med.patient_user_id)
        _scan_schedule_med(db, med, prof, now, grace, created)

    if created:
        db.flush()
    db.commit()
    return created


def create_missed_alerts_from_reminder_escalation(
    db: Session,
    patient_user_id: UUID,
    items: list[tuple[UUID, datetime]],
) -> list[UUID]:
    """Создаёт записи missed_intake_alerts по запросу приложения пациента (игнор 2×15 мин). Commit внутри."""
    now = datetime.now(UTC)
    new_rows: list[MissedIntakeAlert] = []
    for med_id, due_at in items:
        med = db.get(MedRow, med_id)
        if med is None or med.patient_user_id != patient_user_id:
            continue
        bucket: list[MissedIntakeAlert] = []
        _try_add_missed(db, patient_user_id, med_id, due_at, now, bucket)
        new_rows.extend(bucket)
    if new_rows:
        db.flush()
    db.commit()
    return [a.id for a in new_rows]
