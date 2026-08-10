"""A wrong password does not produce a session.

A login that answers 200 to the wrong password is the worst bug available
in this project. The assertion is that no token comes back, not merely that
the status code differs.
"""

import os

import requests

# TestSprite injects TARGET_URL as a global before this file runs. The fallback
# lets a contributor point the same file at their own server with LOCALDRIVE_URL
# and watch it pass or fail, which is the only way to know an assertion is right
# before it is ever uploaded.
BASE_URL = (globals().get("TARGET_URL") or os.environ.get("LOCALDRIVE_URL", "")).rstrip("/")
TIMEOUT = 30


def test_wrong_password_is_refused_without_a_token() -> None:
    response = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        json={
            "username": "an-account-that-does-not-exist",
            "password": "not-the-password",
            "device_name": "testsprite",
            "platform": "web",
        },
        timeout=TIMEOUT,
    )
    assert response.status_code in (400, 401, 403), (
        f"a wrong password was answered {response.status_code}"
    )
    body = response.json()
    assert "access_token" not in body, "a token was issued for a wrong password"


def test_the_error_envelope_names_a_code() -> None:
    response = requests.post(
        f"{BASE_URL}/api/v1/auth/login",
        json={"username": "", "password": ""},
        timeout=TIMEOUT,
    )
    assert response.status_code >= 400, "an empty login was accepted"
    body = response.json()
    assert "error" in body, f"the error envelope is missing from {body!r}"
    assert "code" in body["error"], f"the error envelope carries no code: {body!r}"


test_wrong_password_is_refused_without_a_token()
test_the_error_envelope_names_a_code()
