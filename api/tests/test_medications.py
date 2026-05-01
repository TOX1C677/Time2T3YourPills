import uuid

import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def patient_headers(client: TestClient) -> dict[str, str]:
    r = client.post(
        "/v1/auth/register",
        json={
            "email": "med_pat@example.com",
            "password": "secret12",
            "display_name": "П",
            "role": "patient",
        },
    )
    assert r.status_code == 200
    tok = r.json()["access_token"]
    return {"Authorization": f"Bearer {tok}"}


def test_list_medications_empty_then_upsert(client: TestClient, patient_headers: dict[str, str]):
    r = client.get("/v1/patients/me/medications", headers=patient_headers)
    assert r.status_code == 200
    assert r.json() == []

    mid = str(uuid.uuid4())
    r2 = client.put(
        f"/v1/patients/me/medications/{mid}",
        headers=patient_headers,
        json={
            "name": "Аспирин",
            "dosage": "100 мг",
            "reminder_mode": "interval",
            "interval_minutes": 120,
            "slot_times": None,
        },
    )
    assert r2.status_code == 200
    body = r2.json()
    assert body["id"] == mid
    assert body["name"] == "Аспирин"
    assert body["reminder_mode"] == "interval"

    r3 = client.get("/v1/patients/me/medications", headers=patient_headers)
    assert len(r3.json()) == 1


def test_caregiver_crud_medications(client: TestClient):
    p = client.post(
        "/v1/auth/register",
        json={
            "email": "med_pat2@example.com",
            "password": "secret12",
            "display_name": "П2",
            "role": "patient",
        },
    ).json()
    code = client.get("/v1/patients/me/invite-code", headers={"Authorization": f"Bearer {p['access_token']}"}).json()[
        "token"
    ]

    c = client.post(
        "/v1/auth/register",
        json={
            "email": "med_cg@example.com",
            "password": "secret12",
            "display_name": "О",
            "role": "caregiver",
        },
    ).json()
    ch = {"Authorization": f"Bearer {c['access_token']}"}
    client.post("/v1/caregiver/link-patient", headers=ch, json={"token": code})
    plist = client.get("/v1/caregiver/patients", headers=ch).json()
    assert len(plist) == 1
    pid = str(plist[0]["patient_user_id"])

    mid = str(uuid.uuid4())
    r = client.put(
        f"/v1/caregiver/patients/{pid}/medications/{mid}",
        headers=ch,
        json={
            "name": "Витамин D",
            "dosage": "1 капля",
            "reminder_mode": "schedule",
            "interval_minutes": None,
            "slot_times": ["09:00", "21:00"],
        },
    )
    assert r.status_code == 200
    lst = client.get(f"/v1/caregiver/patients/{pid}/medications", headers=ch).json()
    assert len(lst) == 1
    assert lst[0]["slot_times"] == ["09:00", "21:00"]

    d = client.delete(f"/v1/caregiver/patients/{pid}/medications/{mid}", headers=ch)
    assert d.status_code == 204
    lst2 = client.get(f"/v1/caregiver/patients/{pid}/medications", headers=ch).json()
    assert lst2 == []
