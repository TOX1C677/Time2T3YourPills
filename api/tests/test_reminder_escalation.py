import uuid
from datetime import UTC, datetime, timedelta


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_reminder_escalation_creates_missed_alert(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "esc_pat@example.com",
            "password": "secret12",
            "display_name": "EP",
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
                "name": "Аспирин",
                "dosage": "",
                "reminder_mode": "interval",
                "interval_minutes": 60,
                "slot_times": None,
            },
        ).status_code
        == 200
    )
    due = (datetime.now(UTC) - timedelta(hours=2)).replace(microsecond=0)
    r = client.post(
        "/v1/patients/me/reminder-escalation",
        headers=h,
        json={"items": [{"medication_id": mid, "due_at": due.isoformat().replace("+00:00", "Z")}]},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["new_alerts"] == 1

    r2 = client.post(
        "/v1/patients/me/reminder-escalation",
        headers=h,
        json={"items": [{"medication_id": mid, "due_at": due.isoformat().replace("+00:00", "Z")}]},
    )
    assert r2.status_code == 200
    assert r2.json()["new_alerts"] == 0


def test_reminder_escalation_rejects_other_patients_med(client):
    a = client.post(
        "/v1/auth/register",
        json={
            "email": "esc_a@example.com",
            "password": "secret12",
            "display_name": "A",
            "role": "patient",
        },
    ).json()
    b = client.post(
        "/v1/auth/register",
        json={
            "email": "esc_b@example.com",
            "password": "secret12",
            "display_name": "B",
            "role": "patient",
        },
    ).json()
    ha = _auth(a["access_token"])
    hb = _auth(b["access_token"])
    mid = str(uuid.uuid4())
    assert (
        client.put(
            f"/v1/patients/me/medications/{mid}",
            headers=ha,
            json={
                "name": "Чужое",
                "dosage": "",
                "reminder_mode": "interval",
                "interval_minutes": 60,
                "slot_times": None,
            },
        ).status_code
        == 200
    )
    due = (datetime.now(UTC) - timedelta(hours=1)).replace(microsecond=0)
    r = client.post(
        "/v1/patients/me/reminder-escalation",
        headers=hb,
        json={"items": [{"medication_id": mid, "due_at": due.isoformat().replace("+00:00", "Z")}]},
    )
    assert r.status_code == 200
    assert r.json()["new_alerts"] == 0
