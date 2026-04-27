def _auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_invite_code_for_patient(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "p1@example.com",
            "password": "secret12",
            "display_name": "P1",
            "role": "patient",
        },
    ).json()
    r = client.get("/v1/patients/me/invite-code", headers=_auth_header(reg["access_token"]))
    assert r.status_code == 200
    token = r.json()["token"]
    assert len(token) > 20


def test_caregiver_cannot_read_invite_code(client):
    patient = client.post(
        "/v1/auth/register",
        json={
            "email": "p2@example.com",
            "password": "secret12",
            "display_name": "P2",
            "role": "patient",
        },
    ).json()
    caregiver = client.post(
        "/v1/auth/register",
        json={
            "email": "c1@example.com",
            "password": "secret12",
            "display_name": "C1",
            "role": "caregiver",
        },
    ).json()
    r = client.get("/v1/patients/me/invite-code", headers=_auth_header(caregiver["access_token"]))
    assert r.status_code == 403


def test_link_patient_and_list(client):
    patient = client.post(
        "/v1/auth/register",
        json={
            "email": "p3@example.com",
            "password": "secret12",
            "display_name": "P3",
            "role": "patient",
        },
    ).json()
    code = client.get(
        "/v1/patients/me/invite-code",
        headers=_auth_header(patient["access_token"]),
    ).json()["token"]

    caregiver = client.post(
        "/v1/auth/register",
        json={
            "email": "c2@example.com",
            "password": "secret12",
            "display_name": "C2",
            "role": "caregiver",
        },
    ).json()

    link = client.post(
        "/v1/caregiver/link-patient",
        headers=_auth_header(caregiver["access_token"]),
        json={"token": code},
    )
    assert link.status_code == 200
    assert link.json()["status"] == "linked"

    listed = client.get(
        "/v1/caregiver/patients",
        headers=_auth_header(caregiver["access_token"]),
    )
    assert listed.status_code == 200
    arr = listed.json()
    assert len(arr) == 1
    assert str(arr[0]["patient_user_id"])  # uuid string in json


def test_link_patient_idempotent(client):
    patient = client.post(
        "/v1/auth/register",
        json={
            "email": "p4@example.com",
            "password": "secret12",
            "display_name": "P4",
            "role": "patient",
        },
    ).json()
    code = client.get(
        "/v1/patients/me/invite-code",
        headers=_auth_header(patient["access_token"]),
    ).json()["token"]
    caregiver = client.post(
        "/v1/auth/register",
        json={
            "email": "c3@example.com",
            "password": "secret12",
            "display_name": "C3",
            "role": "caregiver",
        },
    ).json()
    h = _auth_header(caregiver["access_token"])
    assert client.post("/v1/caregiver/link-patient", headers=h, json={"token": code}).json()["status"] == "linked"
    r2 = client.post("/v1/caregiver/link-patient", headers=h, json={"token": code})
    assert r2.status_code == 200
    assert r2.json()["status"] == "already_linked"
