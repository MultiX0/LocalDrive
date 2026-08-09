package app_test

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/app"
	"github.com/MultiX0/LocalDrive/server/internal/config"
)

// harness spins the whole server up against a temp database and temp library,
// so tests exercise the real handlers rather than a mock.
type harness struct {
	t      *testing.T
	app    *app.App
	server *httptest.Server
}

func newHarness(t *testing.T) *harness {
	t.Helper()
	dir := t.TempDir()

	cfg := &config.Config{
		Env:                   "dev",
		Addr:                  ":0",
		LogLevel:              "error",
		DBPath:                filepath.Join(dir, "db", "localdrive.sqlite"),
		LibraryPath:           filepath.Join(dir, "library"),
		ExternalMountsPath:    filepath.Join(dir, "external"),
		JWTSecret:             []byte("test-secret-that-is-long-enough-for-hs256"),
		AccessTokenTTL:        15 * time.Minute,
		RefreshTokenTTL:       24 * time.Hour,
		MaxUploadConcurrency:  4,
		WorkerPoolSize:        2,
		MaxReadConns:          4,
		DefaultQuotaBytes:     10 * 1024 * 1024,
		TrashRetentionDays:    30,
		VersionRetentionCount: 20,
		VersionRetentionDays:  180,
		// deliberately the cheapest argon2 that is still the real algorithm,
		// so the suite is not dominated by password hashing
		Argon2Memory:                 8192,
		Argon2Time:                   1,
		Argon2Threads:                1,
		EnableLANDiscoveryDefault:    false,
		RequireDeviceApprovalDefault: false,
		AllowSelfRegistrationDefault: false,
	}

	logger := slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelError}))
	application, err := app.New(context.Background(), cfg, logger)
	if err != nil {
		t.Fatalf("could not build the server: %v", err)
	}
	server := httptest.NewServer(application.Handler())

	h := &harness{t: t, app: application, server: server}
	t.Cleanup(func() {
		server.Close()
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = application.Close(ctx)
	})
	return h
}

// client is one signed-in device.
type client struct {
	h            *harness
	AccessToken  string
	RefreshToken string
	SessionID    string
	UserID       string
	Username     string
}

func (h *harness) anonymous() *client { return &client{h: h} }

type jsonMap map[string]any

// do sends a request and decodes the response into out, if out is not nil.
func (c *client) do(method, path string, body any, out any) int {
	c.h.t.Helper()
	var reader io.Reader
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			c.h.t.Fatalf("could not encode the request: %v", err)
		}
		reader = bytes.NewReader(encoded)
	}
	req, err := http.NewRequest(method, c.h.server.URL+path, reader)
	if err != nil {
		c.h.t.Fatalf("could not build the request: %v", err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.AccessToken != "" {
		req.Header.Set("Authorization", "Bearer "+c.AccessToken)
	}
	resp, err := c.h.server.Client().Do(req)
	if err != nil {
		c.h.t.Fatalf("%s %s failed: %v", method, path, err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if out != nil && len(raw) > 0 {
		if err := json.Unmarshal(raw, out); err != nil {
			c.h.t.Fatalf("%s %s returned a body that is not json: %s", method, path, string(raw))
		}
	}
	return resp.StatusCode
}

// mustDo fails the test unless the status matches.
func (c *client) mustDo(method, path string, body any, out any, want int) {
	c.h.t.Helper()
	var probe json.RawMessage
	target := out
	if target == nil {
		target = &probe
	}
	got := c.do(method, path, body, target)
	if got != want {
		c.h.t.Fatalf("%s %s returned %d, want %d, body %s", method, path, got, want, string(probe))
	}
}

func (c *client) adopt(token jsonMap) {
	c.h.t.Helper()
	c.AccessToken, _ = token["access_token"].(string)
	c.RefreshToken, _ = token["refresh_token"].(string)
	c.SessionID, _ = token["session_id"].(string)
	if user, ok := token["user"].(map[string]any); ok {
		c.UserID, _ = user["id"].(string)
		c.Username, _ = user["username"].(string)
	}
}

// setupAdmin runs the first-run flow and returns the signed-in admin.
func (h *harness) setupAdmin(username, password string) *client {
	h.t.Helper()
	c := h.anonymous()
	var out jsonMap
	c.mustDo(http.MethodPost, "/api/v1/setup", jsonMap{
		"username": username, "password": password,
		"server_name": "Test Drive", "device_name": "Admin Laptop", "platform": "test",
	}, &out, http.StatusCreated)
	c.adopt(out)
	return c
}

// invite creates an account through the invite flow, the way a household
// member actually joins.
func (h *harness) invite(admin *client, username, password string) *client {
	h.t.Helper()
	var invite jsonMap
	admin.mustDo(http.MethodPost, "/api/v1/admin/invites",
		jsonMap{"label": username}, &invite, http.StatusCreated)
	code, _ := invite["code"].(string)
	if code == "" {
		h.t.Fatal("the invite did not come back with a code")
	}

	member := h.anonymous()
	var out jsonMap
	member.mustDo(http.MethodPost, "/api/v1/auth/register", jsonMap{
		"username": username, "password": password, "invite_code": code,
		"device_name": "Member Phone", "platform": "test",
	}, &out, http.StatusCreated)
	member.adopt(out)
	return member
}

// upload runs a complete tus upload and returns the created node id.
func (c *client) upload(parentID, name, mimeType string, content []byte) string {
	c.h.t.Helper()
	return c.uploadReplacing(parentID, "", name, mimeType, content)
}

// uploadReplacing uploads new bytes over an existing node when nodeID is set.
func (c *client) uploadReplacing(parentID, nodeID, name, mimeType string, content []byte) string {
	c.h.t.Helper()
	meta := []string{
		"filename " + base64.StdEncoding.EncodeToString([]byte(name)),
		"filetype " + base64.StdEncoding.EncodeToString([]byte(mimeType)),
	}
	if parentID != "" {
		meta = append(meta, "parent_id "+base64.StdEncoding.EncodeToString([]byte(parentID)))
	}
	if nodeID != "" {
		meta = append(meta, "node_id "+base64.StdEncoding.EncodeToString([]byte(nodeID)))
	}

	create, err := http.NewRequest(http.MethodPost, c.h.server.URL+"/api/v1/uploads", nil)
	if err != nil {
		c.h.t.Fatal(err)
	}
	create.Header.Set("Tus-Resumable", "1.0.0")
	create.Header.Set("Upload-Length", strconv.Itoa(len(content)))
	create.Header.Set("Upload-Metadata", strings.Join(meta, ","))
	create.Header.Set("Authorization", "Bearer "+c.AccessToken)

	resp, err := c.h.server.Client().Do(create)
	if err != nil {
		c.h.t.Fatalf("upload creation failed: %v", err)
	}
	body, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		c.h.t.Fatalf("upload creation returned %d: %s", resp.StatusCode, string(body))
	}
	location := resp.Header.Get("Location")
	if location == "" {
		c.h.t.Fatal("upload creation did not return a Location")
	}

	patch, err := http.NewRequest(http.MethodPatch, absolute(c.h.server.URL, location), bytes.NewReader(content))
	if err != nil {
		c.h.t.Fatal(err)
	}
	patch.Header.Set("Tus-Resumable", "1.0.0")
	patch.Header.Set("Upload-Offset", "0")
	patch.Header.Set("Content-Type", "application/offset+octet-stream")
	patch.Header.Set("Authorization", "Bearer "+c.AccessToken)

	resp, err = c.h.server.Client().Do(patch)
	if err != nil {
		c.h.t.Fatalf("upload append failed: %v", err)
	}
	body, _ = io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent {
		c.h.t.Fatalf("upload append returned %d: %s", resp.StatusCode, string(body))
	}
	created := resp.Header.Get("Local-Drive-Node-Id")
	if created == "" {
		c.h.t.Fatal("the finished upload did not report a node id")
	}
	return created
}

// uploadInChunks sends content in two pieces with a pause, which is how a
// resumed transfer actually behaves.
func (c *client) uploadInChunks(parentID, name string, content []byte, split int) string {
	c.h.t.Helper()
	meta := []string{
		"filename " + base64.StdEncoding.EncodeToString([]byte(name)),
		"filetype " + base64.StdEncoding.EncodeToString([]byte("application/octet-stream")),
	}
	if parentID != "" {
		meta = append(meta, "parent_id "+base64.StdEncoding.EncodeToString([]byte(parentID)))
	}
	create, _ := http.NewRequest(http.MethodPost, c.h.server.URL+"/api/v1/uploads", nil)
	create.Header.Set("Tus-Resumable", "1.0.0")
	create.Header.Set("Upload-Length", strconv.Itoa(len(content)))
	create.Header.Set("Upload-Metadata", strings.Join(meta, ","))
	create.Header.Set("Authorization", "Bearer "+c.AccessToken)
	resp, err := c.h.server.Client().Do(create)
	if err != nil {
		c.h.t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		c.h.t.Fatalf("upload creation returned %d", resp.StatusCode)
	}
	location := absolute(c.h.server.URL, resp.Header.Get("Location"))

	send := func(offset int, chunk []byte) *http.Response {
		req, _ := http.NewRequest(http.MethodPatch, location, bytes.NewReader(chunk))
		req.Header.Set("Tus-Resumable", "1.0.0")
		req.Header.Set("Upload-Offset", strconv.Itoa(offset))
		req.Header.Set("Content-Type", "application/offset+octet-stream")
		req.Header.Set("Authorization", "Bearer "+c.AccessToken)
		out, err := c.h.server.Client().Do(req)
		if err != nil {
			c.h.t.Fatalf("chunk at %d failed: %v", offset, err)
		}
		return out
	}

	first := send(0, content[:split])
	body, _ := io.ReadAll(first.Body)
	first.Body.Close()
	if first.StatusCode != http.StatusNoContent {
		c.h.t.Fatalf("first chunk returned %d: %s", first.StatusCode, string(body))
	}

	// confirm the server reports exactly what it has, which is what a resuming
	// client asks before sending anything more
	head, _ := http.NewRequest(http.MethodHead, location, nil)
	head.Header.Set("Tus-Resumable", "1.0.0")
	head.Header.Set("Authorization", "Bearer "+c.AccessToken)
	headResp, err := c.h.server.Client().Do(head)
	if err != nil {
		c.h.t.Fatal(err)
	}
	headResp.Body.Close()
	if got := headResp.Header.Get("Upload-Offset"); got != strconv.Itoa(split) {
		c.h.t.Fatalf("resume offset is %q, want %d", got, split)
	}

	second := send(split, content[split:])
	body, _ = io.ReadAll(second.Body)
	second.Body.Close()
	if second.StatusCode != http.StatusNoContent {
		c.h.t.Fatalf("second chunk returned %d: %s", second.StatusCode, string(body))
	}
	nodeID := second.Header.Get("Local-Drive-Node-Id")
	if nodeID == "" {
		c.h.t.Fatal("the resumed upload did not report a node id")
	}
	return nodeID
}

// download fetches a node's bytes, optionally with a Range header.
func (c *client) download(nodeID, rangeHeader string) (int, []byte, http.Header) {
	c.h.t.Helper()
	req, _ := http.NewRequest(http.MethodGet,
		fmt.Sprintf("%s/api/v1/nodes/%s/download", c.h.server.URL, nodeID), nil)
	if c.AccessToken != "" {
		req.Header.Set("Authorization", "Bearer "+c.AccessToken)
	}
	if rangeHeader != "" {
		req.Header.Set("Range", rangeHeader)
	}
	resp, err := c.h.server.Client().Do(req)
	if err != nil {
		c.h.t.Fatalf("download failed: %v", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, body, resp.Header
}

func (c *client) getRaw(path string) (int, []byte) {
	c.h.t.Helper()
	req, _ := http.NewRequest(http.MethodGet, c.h.server.URL+path, nil)
	if c.AccessToken != "" {
		req.Header.Set("Authorization", "Bearer "+c.AccessToken)
	}
	resp, err := c.h.server.Client().Do(req)
	if err != nil {
		c.h.t.Fatalf("GET %s failed: %v", path, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, body
}

// createFolder is the shorthand every test starts with.
func (c *client) createFolder(parentID, name string) string {
	c.h.t.Helper()
	var out jsonMap
	body := jsonMap{"name": name}
	if parentID != "" {
		body["parent_id"] = parentID
	}
	c.mustDo(http.MethodPost, "/api/v1/nodes/folder", body, &out, http.StatusCreated)
	id, _ := out["id"].(string)
	if id == "" {
		c.h.t.Fatal("the folder came back with no id")
	}
	return id
}

func (c *client) listNodes(parentID string) []jsonMap {
	c.h.t.Helper()
	path := "/api/v1/nodes"
	if parentID != "" {
		path += "?parent_id=" + parentID
	}
	var out struct {
		Nodes []jsonMap `json:"nodes"`
	}
	c.mustDo(http.MethodGet, path, nil, &out, http.StatusOK)
	return out.Nodes
}

func absolute(base, location string) string {
	if strings.HasPrefix(location, "http://") || strings.HasPrefix(location, "https://") {
		return location
	}
	return base + location
}

func names(list []jsonMap) []string {
	out := make([]string, 0, len(list))
	for _, item := range list {
		name, _ := item["name"].(string)
		out = append(out, name)
	}
	return out
}

func contains(list []string, want string) bool {
	for _, item := range list {
		if item == want {
			return true
		}
	}
	return false
}

// newUploadCreate builds just the tus creation request, for tests that need to
// inspect the refusal rather than complete a transfer.
func newUploadCreate(t *testing.T, h *harness, c *client, parentID, name string, content []byte) *http.Request {
	t.Helper()
	meta := []string{
		"filename " + base64.StdEncoding.EncodeToString([]byte(name)),
		"filetype " + base64.StdEncoding.EncodeToString([]byte("application/octet-stream")),
	}
	if parentID != "" {
		meta = append(meta, "parent_id "+base64.StdEncoding.EncodeToString([]byte(parentID)))
	}
	req, err := http.NewRequest(http.MethodPost, h.server.URL+"/api/v1/uploads", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Tus-Resumable", "1.0.0")
	req.Header.Set("Upload-Length", strconv.Itoa(len(content)))
	req.Header.Set("Upload-Metadata", strings.Join(meta, ","))
	req.Header.Set("Authorization", "Bearer "+c.AccessToken)
	return req
}
