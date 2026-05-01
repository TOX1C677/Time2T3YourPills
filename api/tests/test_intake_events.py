import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient


def _headers(client: TestClient, email: str, role: str = "patient") -> dict[str, str]:
    r = client.post(
        "/v1/auth/register",
        json={
            "email": email,
            "password": "secret12",
            "display_name": "T",
            "role": role,
        },
    )
    assert r.status_code == 200
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_patient_create_and_list_intake_events(client: TestClient):
    h = _headers(client, "intake_pat@example.com", "patient")
    mid = str(uuid.uuid4())
    put = client.put(
        f"/v1/patients/me/medications/{mid}",
        headers=h,
        json={
            "name": "Тестол",
            "dosage": "1 таб",
            "reminder_mode": "interval",
            "interval_minutes": 60,
            "slot_times": None,
        },
    )
    assert put.status_code == 200

    due = datetime.now(UTC).replace(microsecond=0)
    rec = datetime.now(UTC).replace(microsecond=0)
    cr = client.post(
        "/v1/patients/me/intake-events",
        headers=h,
        json={
            "medication_id": mid,
            "scheduled_at": due.isoformat(),
            "recorded_at": rec.isoformat(),
            "status": "confirmed",
            "medication_name_snapshot": "Тестол",
            "dosage_snapshot": "1 таб",
            "source": "patient_app",
        },
    )
    assert cr.status_code == 201
    body = cr.json()
    assert body["status"] == "confirmed"
    assert body["medication_name_snapshot"] == "Тестол"

    lst = client.get("/v1/patients/me/intake-events", headers=h).json()
    assert len(lst) == 1

    frm = (datetime.now(UTC) - timedelta(days=1)).isoformat()
    to = (datetime.now(UTC) + timedelta(days=1)).isoformat()
    lst2 = client.get(f"/v1/patients/me/intake-events?from={frm}&to={to}", headers=h).json()
    assert len(lst2) == 1


def test_caregiver_reads_patient_intake_events(client: TestClient):
    ph = _headers(client, "intake_pat2@example.com", "patient")
    code = client.get("/v1/patients/me/invite-code", headers=ph).json()["token"]
    pid = client.get("/v1/patients/me/profile", headers=ph).json()["user_id"]

    ch = _headers(client, "intake_cg@example.com", "caregiver")
    client.post("/v1/caregiver/link-patient", headers=ch, json={"token": code})

    due = datetime.now(UTC).replace(microsecond=0)
    rec = datetime.now(UTC).replace(microsecond=0)
    client.post(
        "/v1/patients/me/intake-events",
        headers=ph,
        json={
            "medication_id": None,
            "scheduled_at": due.isoformat(),
            "recorded_at": rec.isoformat(),
            "status": "confirmed",
            "medication_name_snapshot": "X",
            "dosage_snapshot": "y",
            "source": "patient_app",
        },
    )

    lst = client.get(f"/v1/caregiver/patients/{pid}/intake-events", headers=ch).json()
    assert len(lst) == 1
    assert lst[0]["medication_name_snapshot"] == "X"
