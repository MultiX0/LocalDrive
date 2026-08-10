"""A client hosted anywhere can reach this server.

Everyone runs their own server, and the page talking to it is hosted
somewhere this server has never heard of, so the default is to answer any
origin. Media has to stay readable cross-origin too, or every thumbnail
becomes a broken image. This pins both halves.
"""

import os

import requests

# TestSprite injects TARGET_URL as a global before this file runs. The fallback
# lets a contributor point the same file at their own server with LOCALDRIVE_URL
# and watch it pass or fail, which is the only way to know an assertion is right
# before it is ever uploaded.
BASE_URL = (globals().get("TARGET_URL") or os.environ.get("LOCALDRIVE_URL", "")).rstrip("/")
TIMEOUT = 30


ORIGIN = "https://a-client-hosted-elsewhere.example"


def test_the_api_answers_a_foreign_origin() -> None:
    response = requests.get(
        f"{BASE_URL}/api/v1/status",
        timeout=TIMEOUT,
        headers={"Origin": ORIGIN},
    )
    assert response.status_code == 200, f"expected 200, got {response.status_code}"
    allowed = response.headers.get("Access-Control-Allow-Origin")
    assert allowed == ORIGIN, (
        f"Access-Control-Allow-Origin was {allowed!r}; a client hosted elsewhere is shut out"
    )


def test_media_stays_readable_from_another_origin() -> None:
    response = requests.get(
        f"{BASE_URL}/api/v1/status",
        timeout=TIMEOUT,
        headers={"Origin": ORIGIN},
    )
    policy = response.headers.get("Cross-Origin-Resource-Policy")
    assert policy == "cross-origin", (
        f"Cross-Origin-Resource-Policy was {policy!r}; images and video would not render"
    )


def test_a_preflight_allows_what_an_upload_sends() -> None:
    response = requests.options(
        f"{BASE_URL}/api/v1/uploads",
        timeout=TIMEOUT,
        headers={
            "Origin": ORIGIN,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,tus-resumable,upload-metadata",
        },
    )
    assert response.status_code in (200, 204), f"the preflight answered {response.status_code}"
    allowed = response.headers.get("Access-Control-Allow-Headers", "")
    for needed in ("Authorization", "Tus-Resumable", "Upload-Metadata", "Range"):
        assert needed in allowed, f"{needed} is not allowed, so the request it belongs to fails"


test_the_api_answers_a_foreign_origin()
test_media_stays_readable_from_another_origin()
test_a_preflight_allows_what_an_upload_sends()
