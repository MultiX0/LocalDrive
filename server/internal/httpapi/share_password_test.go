package httpapi

import (
	"net/http/httptest"
	"strings"
	"testing"
)

// The share page posts a plain html form, so a browser sends the password
// form encoded. Reading only json meant the password came back empty, the
// share refused to open, and the page re-rendered with the same prompt: a
// correct password looked wrong, with nothing to suggest why.
func TestSharePasswordReadsAFormPost(t *testing.T) {
	req := httptest.NewRequest("POST", "/s/tok", strings.NewReader("password=hunter2"))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	if got := sharePassword(req); got != "hunter2" {
		t.Fatalf("sharePassword = %q, want %q; the share page's own form is unreadable", got, "hunter2")
	}
}

// The apps post json to the same route, and that has to keep working.
func TestSharePasswordReadsAJSONPost(t *testing.T) {
	req := httptest.NewRequest("POST", "/s/tok", strings.NewReader(`{"password":"hunter2"}`))
	req.Header.Set("Content-Type", "application/json")

	if got := sharePassword(req); got != "hunter2" {
		t.Fatalf("sharePassword = %q, want %q", got, "hunter2")
	}
}

// A body with no content type at all still has to be understood, because the
// two clients disagree about what they send and neither is wrong.
func TestSharePasswordDoesNotNeedAContentType(t *testing.T) {
	for name, body := range map[string]string{
		"form": "password=hunter2",
		"json": `{"password":"hunter2"}`,
	} {
		req := httptest.NewRequest("POST", "/s/tok", strings.NewReader(body))
		if got := sharePassword(req); got != "hunter2" {
			t.Errorf("%s body without a content type: got %q, want %q", name, got, "hunter2")
		}
	}
}

// The query and the header are the other two ways in, used by the thumbnail
// and download links on the rendered page.
func TestSharePasswordStillReadsQueryAndHeader(t *testing.T) {
	query := httptest.NewRequest("GET", "/s/tok?password=hunter2", nil)
	if got := sharePassword(query); got != "hunter2" {
		t.Errorf("query: got %q", got)
	}

	header := httptest.NewRequest("GET", "/s/tok", nil)
	header.Header.Set("X-Share-Password", "hunter2")
	if got := sharePassword(header); got != "hunter2" {
		t.Errorf("header: got %q", got)
	}
}

// No password anywhere is the ordinary case for a link without one, and must
// not be mistaken for a blank one.
func TestSharePasswordIsEmptyWhenAbsent(t *testing.T) {
	if got := sharePassword(httptest.NewRequest("GET", "/s/tok", nil)); got != "" {
		t.Errorf("got %q, want empty", got)
	}
	form := httptest.NewRequest("POST", "/s/tok", strings.NewReader("password=%20%20"))
	form.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	if got := sharePassword(form); got != "" {
		t.Errorf("whitespace only: got %q, want empty", got)
	}
}
