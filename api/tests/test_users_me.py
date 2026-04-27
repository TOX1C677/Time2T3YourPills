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
