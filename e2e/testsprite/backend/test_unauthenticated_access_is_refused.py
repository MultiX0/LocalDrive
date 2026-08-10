"""Reading anything owned by an account requires a session.

The most valuable assertion in this project is a refusal. If listing files
without a token ever succeeds, every file on the server is readable by
anyone, and nothing else about the product matters. This pins the refusal.
"""

import os

import requests

# TestSprite injects TARGET_URL as a global before this file runs. The fallback
# lets a contributor point the same file at their own server with LOCALDRIVE_URL
# and watch it pass or fail, which is the only way to know an assertion is right
# before it is ever uploaded.
BASE_URL = (globals().get("TARGET_URL") or os.environ.get("LOCALDRIVE_URL", "")).rstrip("/")
TIMEOUT = 30


PROTECTED = (
    "/api/v1/nodes",
    "/api/v1/me",
    "/api/v1/libraries",
    "/api/v1/sessions",
    "/api/v1/devices/pending",
)


def test_protected_endpoints_refuse_a_request_with_no_token() -> None:
    for path in PROTECTED:
        response = requests.get(f"{BASE_URL}{path}", timeout=TIMEOUT)
        assert response.status_code == 401, (
            f"{path} answered {response.status_code} without a token; expected 401"
        )


def test_a_forged_token_is_refused() -> None:
    headers = {"Authorization": "Bearer not-a-real-token"}
    response = requests.get(f"{BASE_URL}/api/v1/nodes", timeout=TIMEOUT, headers=headers)
    assert response.status_code == 401, (
        f"a forged token was answered {response.status_code}; expected 401"
    )


test_protected_endpoints_refuse_a_request_with_no_token()
test_a_forged_token_is_refused()
