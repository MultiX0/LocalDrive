package db

import (
	"context"
	"database/sql"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

// recorder keeps whatever was logged, so a test can assert on a warning that
// the production code deliberately does not turn into an error.
type recorder struct {
	mu    sync.Mutex
	lines []string
}

func (r *recorder) Enabled(context.Context, slog.Level) bool { return true }

func (r *recorder) Handle(_ context.Context, rec slog.Record) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	line := rec.Message
	rec.Attrs(func(a slog.Attr) bool {
		line += " " + a.Key + "=" + a.Value.String()
		return true
	})
	r.lines = append(r.lines, line)
	return nil
}

func (r *recorder) WithAttrs([]slog.Attr) slog.Handler { return r }
func (r *recorder) WithGroup(string) slog.Handler      { return r }

func (r *recorder) contains(substr string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	for _, line := range r.lines {
		if strings.Contains(line, substr) {
			return true
		}
	}
	return false
}

func openTemp(t *testing.T, log *slog.Logger) (*DB, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "test.sqlite")
	database, err := Open(context.Background(), Options{Path: path, Logger: log})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	return database, path
}

// Every shutdown logged "database table is locked (6)", on every install, for
// as long as the checkpoint existed. The cause was that it went through the
// writer queue, and sqlite refuses a checkpoint inside a transaction.
//
// It was only a warning, so it read as noise. What it actually meant was that
// the log was never folded back in: not on shutdown, and not before a backup
// either, which is the part that could have cost somebody data.
func TestCheckpointOutsideATransaction(t *testing.T) {
	database, path := openTemp(t, slog.New(slog.DiscardHandler))
	defer database.Close()

	if err := database.Write(context.Background(), func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)`)
		return err
	}); err != nil {
		t.Fatalf("create: %v", err)
	}
	for range 50 {
		if err := database.Write(context.Background(), func(ctx context.Context, tx *sql.Tx) error {
			_, err := tx.ExecContext(ctx, `INSERT INTO t (v) VALUES (?)`, "row")
			return err
		}); err != nil {
			t.Fatalf("insert: %v", err)
		}
	}

	if info, err := os.Stat(path + "-wal"); err != nil || info.Size() == 0 {
		t.Skip("nothing in the write-ahead log to collapse")
	}
	if err := database.Checkpoint(context.Background()); err != nil {
		t.Fatalf("checkpoint: %v", err)
	}
	if info, err := os.Stat(path + "-wal"); err == nil && info.Size() > 0 {
		t.Errorf("the log survived the checkpoint at %d bytes", info.Size())
	}
}

// The same collapse has to happen on the way out, with the readers closed
// first so nothing is still holding the file open.
func TestCloseCheckpointsWithoutLocking(t *testing.T) {
	log := &recorder{}
	database, path := openTemp(t, slog.New(log))

	if err := database.Write(context.Background(), func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)`)
		return err
	}); err != nil {
		t.Fatalf("create: %v", err)
	}
	for range 50 {
		if err := database.Write(context.Background(), func(ctx context.Context, tx *sql.Tx) error {
			_, err := tx.ExecContext(ctx, `INSERT INTO t (v) VALUES (?)`, "row")
			return err
		}); err != nil {
			t.Fatalf("insert: %v", err)
		}
	}

	// leave connections idle in the read pool holding their read locks, which
	// is the state a running server is always in
	for range 4 {
		var n int
		if err := database.Read().QueryRow(`SELECT COUNT(*) FROM t`).Scan(&n); err != nil {
			t.Fatalf("read: %v", err)
		}
	}

	if err := database.Close(); err != nil {
		t.Fatalf("close: %v", err)
	}
	if log.contains("could not collapse the write-ahead log") {
		t.Error("the shutdown checkpoint was blocked; the read pool is still being closed too late")
	}

	// a collapsed log is the proof the checkpoint actually ran
	if info, err := os.Stat(path + "-wal"); err == nil && info.Size() > 0 {
		t.Errorf("write-ahead log survived shutdown at %d bytes", info.Size())
	}
}

// Close is reached from more than one path on the way down, and a second call
// must not panic on an already closed channel.
func TestCloseIsIdempotent(t *testing.T) {
	database, _ := openTemp(t, slog.New(slog.DiscardHandler))
	if err := database.Close(); err != nil {
		t.Fatalf("first close: %v", err)
	}
	if err := database.Close(); err != nil {
		t.Fatalf("second close: %v", err)
	}
}

// A write arriving after shutdown has to be refused rather than block forever
// on a queue nothing is serving.
func TestWriteAfterCloseIsRefused(t *testing.T) {
	database, _ := openTemp(t, slog.New(slog.DiscardHandler))
	if err := database.Close(); err != nil {
		t.Fatalf("close: %v", err)
	}
	err := database.Write(context.Background(), func(context.Context, *sql.Tx) error { return nil })
	if err == nil {
		t.Fatal("a write after close was accepted")
	}
}
