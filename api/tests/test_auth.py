def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_register_patient_and_login(client):
    r = client.post(
        "/v1/auth/register",
        json={
            "email": "pat@example.com",
            "password": "secret12",
            "display_name": "Пациент",
            "role": "patient",
        },
    )
    assert r.status_code == 200
    data = r.json()
    assert "access_token" in data
    assert data["role"] == "patient"
    assert data["email"] == "pat@example.com"

    r2 = client.post(
        "/v1/auth/login",
        json={"email": "pat@example.com", "password": "secret12"},
    )
    assert r2.status_code == 200
    assert r2.json()["role"] == "patient"


def test_register_duplicate_email(client):
    body = {
        "email": "dup@example.com",
        "password": "secret12",
        "display_name": "A",
        "role": "patient",
    }
    assert client.post("/v1/auth/register", json=body).status_code == 200
    r = client.post("/v1/auth/register", json=body)
    assert r.status_code == 409


def test_refresh_token(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "ref@example.com",
            "password": "secret12",
            "display_name": "R",
            "role": "caregiver",
        },
    ).json()
    r = client.post(
        "/v1/auth/refresh",
        json={"refresh_token": reg["refresh_token"]},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["role"] == "caregiver"
    assert "access_token" in body and "refresh_token" in body


def test_logout_revokes_refresh_token(client):
    reg = client.post(
        "/v1/auth/register",
        json={
            "email": "out@example.com",
            "password": "secret12",
            "display_name": "O",
            "role": "patient",
        },
    ).json()
    rt = reg["refresh_token"]
    lo = client.post("/v1/auth/logout", json={"refresh_token": rt})
    assert lo.status_code == 204
    r2 = client.post("/v1/auth/refresh", json={"refresh_token": rt})
    assert r2.status_code == 401
