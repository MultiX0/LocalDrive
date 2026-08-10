"""An unknown share token is refused.

Share links are the only unauthenticated surface in the product. A token
that does not exist has to answer 404 rather than anything that hints at
what a real token would look like.
"""

import os

import requests

# TestSprite injects TARGET_URL as a global before this file runs. The fallback
# lets a contributor point the same file at their own server with LOCALDRIVE_URL
# and watch it pass or fail, which is the only way to know an assertion is right
# before it is ever uploaded.
BASE_URL = (globals().get("TARGET_URL") or os.environ.get("LOCALDRIVE_URL", "")).rstrip("/")
TIMEOUT = 30


def test_an_unknown_share_token_is_not_found() -> None:
    response = requests.get(
        f"{BASE_URL}/s/thisTokenDoesNotExistAtAll",
        timeout=TIMEOUT,
        allow_redirects=False,
    )
    assert response.status_code == 404, (
        f"an unknown share token answered {response.status_code}; expected 404"
    )


def test_the_share_page_script_is_served_by_this_server() -> None:
    # vendored rather than loaded from a cdn, so opening a share link tells
    # nobody but this server that it happened
    response = requests.get(f"{BASE_URL}/s/assets/htmx.js", timeout=TIMEOUT)
    assert response.status_code == 200, (
        f"the share page script answered {response.status_code}; expected 200"
    )


test_an_unknown_share_token_is_not_found()
test_the_share_page_script_is_served_by_this_server()
