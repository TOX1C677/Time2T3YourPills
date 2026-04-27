def _h(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


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
        json={"first_name": "Иван", "middle_name": "Петрович"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["first_name"] == "Иван"
    assert body["middle_name"] == "Петрович"
