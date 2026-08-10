package middleware

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func ask(t *testing.T, allowed []string, method, origin string) *http.Response {
	t.Helper()
	handler := CORS(allowed)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	req := httptest.NewRequest(method, "/api/v1/nodes", nil)
	if origin != "" {
		req.Header.Set("Origin", origin)
	}
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	return rec.Result()
}

// Everyone runs their own server, and the page talking to it is hosted
// somewhere this server has never heard of. A list it cannot know in advance
// is not a list it can enforce, so an unconfigured server answers anyone.
func TestAnyOriginIsAllowedByDefault(t *testing.T) {
	for _, origin := range []string{
		"https://localdrive-4e50f.web.app",
		"http://localhost:3000",
		"https://drive.example.com",
	} {
		resp := ask(t, nil, http.MethodGet, origin)
		if got := resp.Header.Get("Access-Control-Allow-Origin"); got != origin {
			t.Errorf("origin %s was answered with %q", origin, got)
		}
		if resp.Header.Get("Vary") != "Origin" {
			t.Errorf("origin %s: the answer differs per origin and must say so", origin)
		}
	}
}

// The origin is echoed rather than answered with a wildcard, because a
// wildcard cannot be combined with credentials and every request here carries
// a token.
func TestCredentialsNeverPairWithAWildcard(t *testing.T) {
	resp := ask(t, nil, http.MethodGet, "https://drive.example.com")
	if resp.Header.Get("Access-Control-Allow-Origin") == "*" &&
		resp.Header.Get("Access-Control-Allow-Credentials") == "true" {
		t.Fatal("a wildcard with credentials is refused by every browser")
	}
}

// Setting the list is an operator narrowing it deliberately, and that has to
// keep working.
func TestAConfiguredListStillRestricts(t *testing.T) {
	allowed := []string{"https://drive.example.com"}
	if got := ask(t, allowed, http.MethodGet, "https://drive.example.com").
		Header.Get("Access-Control-Allow-Origin"); got != "https://drive.example.com" {
		t.Errorf("the listed origin was refused: %q", got)
	}
	if got := ask(t, allowed, http.MethodGet, "https://somewhere.else").
		Header.Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("an origin outside the list was allowed: %q", got)
	}
}

// A preflight has to answer without reaching the handler, and name everything
// the client sends. Range is what a video element asks with, and leaving it
// out means playback never starts.
func TestPreflightNamesWhatTheClientSends(t *testing.T) {
	resp := ask(t, nil, http.MethodOptions, "https://drive.example.com")
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("preflight answered %d", resp.StatusCode)
	}
	headers := resp.Header.Get("Access-Control-Allow-Headers")
	for _, needed := range []string{"Authorization", "Range", "Tus-Resumable", "Upload-Offset", "Upload-Metadata"} {
		if !strings.Contains(headers, needed) {
			t.Errorf("%s is not allowed, so the request it belongs to fails", needed)
		}
	}
}

// A cross-origin response hides every header not named here. Without them an
// upload cannot find where to continue, a download loses its filename, and a
// video cannot be seeked.
func TestTheHeadersTheClientHasToReadAreExposed(t *testing.T) {
	exposed := ask(t, nil, http.MethodGet, "https://drive.example.com").
		Header.Get("Access-Control-Expose-Headers")
	for _, needed := range []string{
		"Location", "Upload-Offset", "Tus-Resumable",
		"Content-Length", "Content-Range", "Accept-Ranges", "Content-Disposition",
	} {
		if !strings.Contains(exposed, needed) {
			t.Errorf("%s is hidden from the client that needs to read it", needed)
		}
	}
}

// A thumbnail, a video and an audio file are fetched by the element itself
// rather than by script, and same-site makes the browser drop the response
// before anything can react to it: every picture becomes a broken image with
// no error anybody can act on.
func TestMediaIsReadableFromAnotherOrigin(t *testing.T) {
	handler := SecurityHeaders(true)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/v1/nodes/x/thumbnail", nil))
	if got := rec.Header().Get("Cross-Origin-Resource-Policy"); got != "cross-origin" {
		t.Fatalf("Cross-Origin-Resource-Policy is %q, so images and video will not render", got)
	}
}
