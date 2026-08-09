package app_test

import (
	"net/http"
	"net/url"
	"testing"
)

// An img, video or audio element fetches its own URL and offers no hook to add
// a header to it, so the three routes one of those points at also accept the
// access token in the query string. The rest of the API must not: a token in a
// URL ends up in history and in logs, and that trade is only worth making
// where there is no alternative.
func TestMediaRoutesAcceptQueryToken(t *testing.T) {
	h := newHarness(t)
	admin := h.setupAdmin("owner", "correct horse battery")

	content := []byte("the bytes behind the thumbnail")
	nodeID := admin.upload("", "note.txt", "text/plain", content)

	anon := h.anonymous()
	signed := "?access_token=" + url.QueryEscape(admin.AccessToken)

	status, body := anon.getRaw("/api/v1/nodes/" + nodeID + "/download" + signed)
	if status != http.StatusOK {
		t.Fatalf("download with a query token: got %d, want 200", status)
	}
	if string(body) != string(content) {
		t.Fatalf("download with a query token returned %q", body)
	}

	if status, _ := anon.getRaw("/api/v1/nodes/" + nodeID + "/thumbnail" + signed); status == http.StatusUnauthorized {
		t.Fatal("a thumbnail refused a valid query token")
	}

	if status, _ := anon.getRaw("/api/v1/nodes/" + nodeID + "/download?access_token=not-a-token"); status != http.StatusUnauthorized {
		t.Fatalf("download with a forged query token: got %d, want 401", status)
	}

	if status, _ := anon.getRaw("/api/v1/nodes/" + nodeID + "/download"); status != http.StatusUnauthorized {
		t.Fatalf("download with no token at all: got %d, want 401", status)
	}

	// the door is narrow on purpose: the same token must not open anything else
	if status, _ := anon.getRaw("/api/v1/nodes" + signed); status != http.StatusUnauthorized {
		t.Fatalf("listing nodes with a query token: got %d, want 401", status)
	}
	if status, _ := anon.getRaw("/api/v1/me" + signed); status != http.StatusUnauthorized {
		t.Fatalf("reading the account with a query token: got %d, want 401", status)
	}
}
