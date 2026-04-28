"""Worker POST /v1/system/missed-intake-scan: пропуски по интервалу при нулевом grace."""

import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app import config


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_worker_missed_intake_scan_interval_with_zero_grace(client: TestClient, monkeypatch):
    """При grace=0 сканер находит пропущенные слоты после последнего подтверждённого приёма."""
    monkeypatch.setattr(config.settings, "worker_api_key", "wk-esc-only", raising=False)
    monkeypatch.setattr(config.settings, "missed_intake_grace_minutes", 0, raising=False)

    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "wk_esc_only@example.com",
            "password": "secret12",
            "display_name": "WE",
            "role": "patient",
        },
    ).json()
    h = _auth(reg["access_token"])
    mid = str(uuid.uuid4())
    assert (
        client.put(
            f"/v1/patients/me/medications/{mid}",
            headers=h,
            json={
                "name": "Витамин",
                "dosage": "",
                "reminder_mode": "interval",
                "interval_minutes": 60,
                "slot_times": None,
            },
        ).status_code
        == 200
    )

    last_due = datetime.now(UTC).replace(microsecond=0) - timedelta(hours=3)
    rec = datetime.now(UTC).replace(microsecond=0)
    assert (
        client.post(
            "/v1/patients/me/intake-events",
            headers=h,
            json={
                "medication_id": mid,
                "scheduled_at": last_due.isoformat(),
                "recorded_at": rec.isoformat(),
                "status": "confirmed",
                "medication_name_snapshot": "Витамин",
                "dosage_snapshot": "",
                "source": "patient_app",
            },
        ).status_code
        == 201
    )

    scan = client.post("/v1/system/missed-intake-scan", headers={"X-Worker-Key": "wk-esc-only"})
    assert scan.status_code == 200
    body = scan.json()
    assert "new_alerts" in body and "emails_sent" in body
    assert body["new_alerts"] >= 1
