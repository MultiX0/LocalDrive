"""The status endpoint keeps the shape every client reads.

Every client decides which screen to show from this response: whether the
server still needs setting up, and whether it is ready. A renamed or dropped
field strands every client on the wrong screen, so the shape is a public
contract rather than an implementation detail.
"""

import os

import requests

# TestSprite injects TARGET_URL as a global before this file runs. The fallback
# lets a contributor point the same file at their own server with LOCALDRIVE_URL
# and watch it pass or fail, which is the only way to know an assertion is right
# before it is ever uploaded.
BASE_URL = (globals().get("TARGET_URL") or os.environ.get("LOCALDRIVE_URL", "")).rstrip("/")
TIMEOUT = 30


def test_healthz_reports_ok() -> None:
    response = requests.get(f"{BASE_URL}/healthz", timeout=TIMEOUT)
    assert response.status_code == 200, f"expected 200, got {response.status_code}"
    body = response.json()
    assert body.get("status") == "ok", f"expected status ok, got {body!r}"


def test_status_names_the_server_and_its_setup_state() -> None:
    response = requests.get(f"{BASE_URL}/api/v1/status", timeout=TIMEOUT)
    assert response.status_code == 200, f"expected 200, got {response.status_code}"
    body = response.json()
    for field in ("name", "server_id", "version", "setup_required", "ready"):
        assert field in body, f"{field} is missing from the status response: {body!r}"
    assert isinstance(body["setup_required"], bool), "setup_required must be a boolean"
    assert isinstance(body["ready"], bool), "ready must be a boolean"


test_healthz_reports_ok()
test_status_names_the_server_and_its_setup_state()
