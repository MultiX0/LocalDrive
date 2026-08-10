package app_test

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/app"
	"github.com/MultiX0/LocalDrive/server/internal/config"
)

// warnings keeps anything logged at warn or above, so a test can hold the
// shutdown to the standard of being silent rather than merely finishing.
type warnings struct {
	mu    sync.Mutex
	lines []string
}

func (w *warnings) Enabled(_ context.Context, level slog.Level) bool {
	return level >= slog.LevelWarn
}

func (w *warnings) Handle(_ context.Context, rec slog.Record) error {
	w.mu.Lock()
	defer w.mu.Unlock()
	line := rec.Message
	rec.Attrs(func(a slog.Attr) bool {
		line += " " + a.Key + "=" + a.Value.String()
		return true
	})
	w.lines = append(w.lines, line)
	return nil
}

func (w *warnings) WithAttrs([]slog.Attr) slog.Handler { return w }
func (w *warnings) WithGroup(string) slog.Handler      { return w }

func (w *warnings) all() []string {
	w.mu.Lock()
	defer w.mu.Unlock()
	return append([]string(nil), w.lines...)
}

// Every stop logged "service shutdown was not clean: database table is locked
// (6)". Being a warning rather than a failure is why it was ignored, and what
// it meant was that the write-ahead log was never folded back into the
// database on the way out.
//
// This is the whole shutdown path, not the database on its own, because the
// order the pieces close in is exactly what was wrong.
func TestShutdownIsClean(t *testing.T) {
	dir := t.TempDir()
	cfg := &config.Config{
		Env:                          "dev",
		Addr:                         ":0",
		LogLevel:                     "warn",
		DBPath:                       filepath.Join(dir, "db", "localdrive.sqlite"),
		LibraryPath:                  filepath.Join(dir, "library"),
		ExternalMountsPath:           filepath.Join(dir, "external"),
		JWTSecret:                    []byte("test-secret-that-is-long-enough-for-hs256"),
		AccessTokenTTL:               15 * time.Minute,
		RefreshTokenTTL:              24 * time.Hour,
		MaxUploadConcurrency:         4,
		WorkerPoolSize:               2,
		MaxReadConns:                 4,
		DefaultQuotaBytes:            10 * 1024 * 1024,
		TrashRetentionDays:           30,
		VersionRetentionCount:        20,
		VersionRetentionDays:         180,
		Argon2Memory:                 8192,
		Argon2Time:                   1,
		Argon2Threads:                1,
		EnableLANDiscoveryDefault:    false,
		RequireDeviceApprovalDefault: false,
		AllowSelfRegistrationDefault: false,
	}

	recorded := &warnings{}
	application, err := app.New(context.Background(), cfg, slog.New(recorded))
	if err != nil {
		t.Fatalf("could not build the server: %v", err)
	}
	server := httptest.NewServer(application.Handler())

	// real traffic first, so both pools have live connections and the log has
	// something in it to collapse
	for range 5 {
		resp, err := http.Get(server.URL + "/api/v1/status")
		if err != nil {
			t.Fatalf("status: %v", err)
		}
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}
	server.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := application.Close(ctx); err != nil {
		t.Fatalf("shutdown reported an error: %v", err)
	}

	for _, line := range recorded.all() {
		if strings.Contains(line, "locked") || strings.Contains(line, "write-ahead log") {
			t.Errorf("shutdown was not clean: %s", line)
		}
	}
}
