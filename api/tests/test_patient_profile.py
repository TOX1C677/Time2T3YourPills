def _h(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_register_sets_patient_first_name_from_display_name(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "prefill@example.com",
            "password": "secret12",
            "display_name": "Мария",
            "role": "patient",
        },
    ).json()
    r = client.get("/v1/patients/me/profile", headers=_h(reg["access_token"]))
    assert r.status_code == 200
    assert r.json()["first_name"] == "Мария"
    assert r.json()["last_name"] == ""


def test_patch_patient_profile(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "prof@example.com",
            "password": "secret12",
            "display_name": "P",
            "role": "patient",
        },
    ).json()
    r = client.patch(
        "/v1/patients/me/profile",
        headers=_h(reg["access_token"]),
        json={"first_name": "Иван", "last_name": "Иванов", "middle_name": "Петрович"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["first_name"] == "Иван"
    assert body["last_name"] == "Иванов"
    assert body["middle_name"] == "Петрович"
