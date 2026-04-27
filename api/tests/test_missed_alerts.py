import uuid
from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from app import config


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_worker_scan_creates_missed_alert(client: TestClient, monkeypatch):
    monkeypatch.setattr(config.settings, "worker_api_key", "wk-test", raising=False)
    monkeypatch.setattr(config.settings, "missed_intake_grace_minutes", 0, raising=False)

    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "miss_pat@example.com",
            "password": "secret12",
            "display_name": "MP",
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
                "name": "Ибупрофен",
                "dosage": "1",
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
                "medication_name_snapshot": "Ибупрофен",
                "dosage_snapshot": "1",
                "source": "patient_app",
            },
        ).status_code
        == 201
    )

    scan = client.post("/v1/system/missed-intake-scan", headers={"X-Worker-Key": "wk-test"})
    assert scan.status_code == 200
    body = scan.json()
    assert body["new_alerts"] >= 1
    assert body.get("emails_sent", 0) == 0


def test_worker_schedule_missed_alert(client: TestClient, monkeypatch):
    monkeypatch.setattr(config.settings, "worker_api_key", "wk-sch", raising=False)
    monkeypatch.setattr(config.settings, "missed_intake_grace_minutes", 0, raising=False)

    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "miss_pat_sched@example.com",
            "password": "secret12",
            "display_name": "MPS",
            "role": "patient",
        },
    ).json()
    h = _auth(reg["access_token"])
    assert client.patch("/v1/patients/me/profile", headers=h, json={"timezone": "UTC"}).status_code == 200

    past = datetime.now(UTC) - timedelta(hours=2)
    slot = f"{past.hour:02d}:{past.minute:02d}"
    mid = str(uuid.uuid4())
    assert (
        client.put(
            f"/v1/patients/me/medications/{mid}",
            headers=h,
            json={
                "name": "По расписанию",
                "dosage": "",
                "reminder_mode": "schedule",
                "interval_minutes": None,
                "slot_times": [slot],
            },
        ).status_code
        == 200
    )

    scan = client.post("/v1/system/missed-intake-scan", headers={"X-Worker-Key": "wk-sch"})
    assert scan.status_code == 200
    assert scan.json()["new_alerts"] >= 1


def test_worker_sends_email_when_smtp_stubbed(client: TestClient, monkeypatch):
    sent: list[tuple[str, list[str]]] = []

    def fake_smtp(msg, recipients):
        sent.append((msg["Subject"], list(recipients)))

    monkeypatch.setattr(config.settings, "worker_api_key", "wk-mail", raising=False)
    monkeypatch.setattr(config.settings, "missed_intake_grace_minutes", 0, raising=False)
    monkeypatch.setattr(config.settings, "smtp_host", "localhost", raising=False)
    monkeypatch.setattr(config.settings, "smtp_from_email", "noreply@example.com", raising=False)
    monkeypatch.setattr("app.services.caregiver_email._smtp_send", fake_smtp)

    patient = client.post(
        "/v1/auth/register",
        json={
            "email": "miss_pat_mail@example.com",
            "password": "secret12",
            "display_name": "MPM",
            "role": "patient",
        },
    ).json()
    ph = _auth(patient["access_token"])
    code = client.get("/v1/patients/me/invite-code", headers=ph).json()["token"]

    caregiver = client.post(
        "/v1/auth/register",
        json={
            "email": "miss_cg_mail@example.com",
            "password": "secret12",
            "display_name": "MCGM",
            "role": "caregiver",
        },
    ).json()
    ch = _auth(caregiver["access_token"])
    assert client.post("/v1/caregiver/link-patient", headers=ch, json={"token": code}).status_code == 200

    mid = str(uuid.uuid4())
    client.put(
        f"/v1/patients/me/medications/{mid}",
        headers=ph,
        json={
            "name": "ДляПисьма",
            "dosage": "",
            "reminder_mode": "interval",
            "interval_minutes": 60,
            "slot_times": None,
        },
    )
    last_due = datetime.now(UTC).replace(microsecond=0) - timedelta(hours=3)
    client.post(
        "/v1/patients/me/intake-events",
        headers=ph,
        json={
            "medication_id": mid,
            "scheduled_at": last_due.isoformat(),
            "recorded_at": last_due.isoformat(),
            "status": "confirmed",
            "medication_name_snapshot": "ДляПисьма",
            "dosage_snapshot": "",
            "source": "patient_app",
        },
    )

    scan = client.post("/v1/system/missed-intake-scan", headers={"X-Worker-Key": "wk-mail"})
    assert scan.status_code == 200
    assert scan.json()["new_alerts"] >= 1
    assert scan.json()["emails_sent"] >= 1
    assert len(sent) >= 1
    assert "ДляПисьма" in sent[0][0]


def test_caregiver_lists_missed_alerts(client: TestClient, monkeypatch):
    monkeypatch.setattr(config.settings, "worker_api_key", "wk2", raising=False)
    monkeypatch.setattr(config.settings, "missed_intake_grace_minutes", 0, raising=False)

    patient = client.post(
        "/v1/auth/register",
        json={
            "email": "miss_pat2@example.com",
            "password": "secret12",
            "display_name": "MP2",
            "role": "patient",
        },
    ).json()
    ph = _auth(patient["access_token"])
    code = client.get("/v1/patients/me/invite-code", headers=ph).json()["token"]

    caregiver = client.post(
        "/v1/auth/register",
        json={
            "email": "miss_cg@example.com",
            "password": "secret12",
            "display_name": "MCG",
            "role": "caregiver",
        },
    ).json()
    ch = _auth(caregiver["access_token"])
    assert client.post("/v1/caregiver/link-patient", headers=ch, json={"token": code}).status_code == 200

    mid = str(uuid.uuid4())
    client.put(
        f"/v1/patients/me/medications/{mid}",
        headers=ph,
        json={
            "name": "Витамин",
            "dosage": "",
            "reminder_mode": "interval",
            "interval_minutes": 120,
            "slot_times": None,
        },
    )
    last_due = datetime.now(UTC).replace(microsecond=0) - timedelta(hours=5)
    client.post(
        "/v1/patients/me/intake-events",
        headers=ph,
        json={
            "medication_id": mid,
            "scheduled_at": last_due.isoformat(),
            "recorded_at": last_due.isoformat(),
            "status": "confirmed",
            "medication_name_snapshot": "Витамин",
            "dosage_snapshot": "",
            "source": "patient_app",
        },
    )

    client.post("/v1/system/missed-intake-scan", headers={"X-Worker-Key": "wk2"})

    r = client.get("/v1/caregiver/alerts", headers=ch)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    row = data[0]
    assert row["medication_name"] == "Витамин"
    assert "due_at" in row


def test_link_patient_rate_limit(client: TestClient, monkeypatch):
    monkeypatch.setattr(config.settings, "caregiver_link_attempts_per_hour", 3, raising=False)

    patient = client.post(
        "/v1/auth/register",
        json={
            "email": "rl_p@example.com",
            "password": "secret12",
            "display_name": "RLP",
            "role": "patient",
        },
    ).json()
    code = client.get(
        "/v1/patients/me/invite-code",
        headers=_auth(patient["access_token"]),
    ).json()["token"]

    cg = client.post(
        "/v1/auth/register",
        json={
            "email": "rl_c@example.com",
            "password": "secret12",
            "display_name": "RLC",
            "role": "caregiver",
        },
    ).json()
    h = _auth(cg["access_token"])

    for _ in range(3):
        r = client.post("/v1/caregiver/link-patient", headers=h, json={"token": "bad-token"})
        assert r.status_code in (404, 429)

    r4 = client.post("/v1/caregiver/link-patient", headers=h, json={"token": code})
    assert r4.status_code == 429
