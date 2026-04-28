def _headers(tok: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {tok}"}


def test_get_me_includes_ui_bold_fonts(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "me@example.com",
            "password": "secret12",
            "display_name": "U",
            "role": "patient",
        },
    ).json()
    r = client.get("/v1/users/me", headers=_headers(reg["access_token"]))
    assert r.status_code == 200
    body = r.json()
    assert body["email"] == "me@example.com"
    assert body["role"] == "patient"
    assert body["ui_bold_fonts"] is False


def test_patch_ui_bold_fonts(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "bold@example.com",
            "password": "secret12",
            "display_name": "B",
            "role": "caregiver",
        },
    ).json()
    tok = reg["access_token"]
    r = client.patch("/v1/users/me", headers=_headers(tok), json={"ui_bold_fonts": True})
    assert r.status_code == 200
    assert r.json()["ui_bold_fonts"] is True
    r2 = client.get("/v1/users/me", headers=_headers(tok))
    assert r2.json()["ui_bold_fonts"] is True


def test_me_requires_auth(client):
    assert client.get("/v1/users/me").status_code == 401


def test_delete_me_requires_auth(client):
    assert client.delete("/v1/users/me").status_code == 401


def test_delete_me_removes_user_and_tokens_invalid(client):
    import uuid

    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "gone@example.com",
            "password": "secret12",
            "display_name": "G",
            "role": "patient",
        },
    ).json()
    tok = reg["access_token"]
    h = _headers(tok)
    mid = str(uuid.uuid4())
    put = client.put(
        f"/v1/patients/me/medications/{mid}",
        headers=h,
        json={
            "name": "X",
            "dosage": "",
            "reminder_mode": "interval",
            "interval_minutes": 60,
            "slot_times": None,
        },
    )
    assert put.status_code == 200
    assert client.delete("/v1/users/me", headers=h).status_code == 204
    assert client.get("/v1/users/me", headers=h).status_code == 401
    assert client.get("/v1/patients/me/medications", headers=h).status_code == 401


def test_delete_patient_unlinks_caregiver(client):
    patient = client.post(
        "/v1/auth/register",
        json={
            "email": "pdel@example.com",
            "password": "secret12",
            "display_name": "P",
            "role": "patient",
        },
    ).json()
    code = client.get("/v1/patients/me/invite-code", headers=_headers(patient["access_token"])).json()["token"]
    caregiver = client.post(
        "/v1/auth/register",
        json={
            "email": "cgdel@example.com",
            "password": "secret12",
            "display_name": "C",
            "role": "caregiver",
        },
    ).json()
    ch = _headers(caregiver["access_token"])
    assert client.post("/v1/caregiver/link-patient", headers=ch, json={"token": code}).status_code == 200
    assert len(client.get("/v1/caregiver/patients", headers=ch).json()) == 1

    assert client.delete("/v1/users/me", headers=_headers(patient["access_token"])).status_code == 204

    listed = client.get("/v1/caregiver/patients", headers=ch)
    assert listed.status_code == 200
    assert listed.json() == []
