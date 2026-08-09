// Package db owns the SQLite connection model: a read pool that WAL keeps
// unblocked, and one dedicated writer goroutine so nothing ever contends for
// the single write lock.
package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"time"

	_ "modernc.org/sqlite"
)

// ErrClosed is returned once the writer has been shut down.
var ErrClosed = errors.New("db: closed")

// DB holds both connection pools and the writer queue.
type DB struct {
	read   *sql.DB
	write  *sql.DB
	jobs   chan writeJob
	done   chan struct{}
	closed chan struct{}
	log    *slog.Logger
	path   string
}

type writeJob struct {
	ctx context.Context
	fn  func(context.Context, *sql.Tx) error
	res chan error
}

// Options configures Open.
type Options struct {
	Path         string
	MaxReadConns int
	Logger       *slog.Logger
	// QueueDepth bounds how many writes can wait; a full queue means the
	// caller blocks rather than the server growing memory without bound.
	QueueDepth int
}

// Open prepares the database file, applies pragmas, and starts the writer.
func Open(ctx context.Context, opts Options) (*DB, error) {
	if opts.Logger == nil {
		opts.Logger = slog.Default()
	}
	if opts.MaxReadConns <= 0 {
		opts.MaxReadConns = 4
	}
	if opts.QueueDepth <= 0 {
		opts.QueueDepth = 256
	}
	if err := os.MkdirAll(filepath.Dir(opts.Path), 0o750); err != nil {
		return nil, fmt.Errorf("db: create directory: %w", err)
	}

	writeDSN := dsn(opts.Path, false)
	readDSN := dsn(opts.Path, true)

	write, err := sql.Open("sqlite", writeDSN)
	if err != nil {
		return nil, fmt.Errorf("db: open write handle: %w", err)
	}
	write.SetMaxOpenConns(1)
	write.SetMaxIdleConns(1)
	write.SetConnMaxLifetime(0)
	if err := write.PingContext(ctx); err != nil {
		write.Close()
		return nil, fmt.Errorf("db: ping write handle: %w", err)
	}

	read, err := sql.Open("sqlite", readDSN)
	if err != nil {
		write.Close()
		return nil, fmt.Errorf("db: open read pool: %w", err)
	}
	read.SetMaxOpenConns(opts.MaxReadConns)
	read.SetMaxIdleConns(opts.MaxReadConns)
	read.SetConnMaxLifetime(time.Hour)
	if err := read.PingContext(ctx); err != nil {
		read.Close()
		write.Close()
		return nil, fmt.Errorf("db: ping read pool: %w", err)
	}

	d := &DB{
		read:   read,
		write:  write,
		jobs:   make(chan writeJob, opts.QueueDepth),
		done:   make(chan struct{}),
		closed: make(chan struct{}),
		log:    opts.Logger,
		path:   opts.Path,
	}
	go d.writerLoop()
	return d, nil
}

func dsn(path string, readonly bool) string {
	base := "file:" + filepath.ToSlash(path) +
		"?_pragma=journal_mode(WAL)" +
		"&_pragma=busy_timeout(10000)" +
		"&_pragma=foreign_keys(1)" +
		"&_pragma=synchronous(NORMAL)" +
		"&_pragma=cache_size(-8000)"
	if readonly {
		// read connections may never write, and never take a write lock
		base += "&_query_only=1"
	} else {
		// immediate so a write transaction fails fast instead of upgrading
		base += "&_txlock=immediate"
	}
	return base
}

// Read returns the read pool. Never use it for writes; query_only is on.
func (d *DB) Read() *sql.DB { return d.read }

// Path returns the database file path, used by the backup helper.
func (d *DB) Path() string { return d.path }

// Write runs fn inside a transaction on the single writer goroutine. fn must
// not call Write again; that would deadlock.
func (d *DB) Write(ctx context.Context, fn func(context.Context, *sql.Tx) error) error {
	res := make(chan error, 1)
	job := writeJob{ctx: ctx, fn: fn, res: res}
	select {
	case <-d.done:
		return ErrClosed
	case d.jobs <- job:
	case <-ctx.Done():
		return ctx.Err()
	}
	select {
	case err := <-res:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (d *DB) writerLoop() {
	defer close(d.closed)
	for job := range d.jobs {
		job.res <- d.runJob(job)
	}
}

func (d *DB) runJob(job writeJob) (err error) {
	ctx := job.ctx
	if ctx == nil {
		ctx = context.Background()
	}
	if ctx.Err() != nil {
		return ctx.Err()
	}
	tx, err := d.write.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("db: begin: %w", err)
	}
	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback()
			err = fmt.Errorf("db: panic in write transaction: %v", p)
			d.log.Error("write transaction panicked", "panic", p)
		}
	}()
	if err := job.fn(ctx, tx); err != nil {
		_ = tx.Rollback()
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("db: commit: %w", err)
	}
	return nil
}

// Close drains outstanding writes and shuts both pools down.
func (d *DB) Close() error {
	select {
	case <-d.done:
		return nil
	default:
	}
	close(d.done)
	close(d.jobs)
	<-d.closed
	var firstErr error
	if err := d.write.Close(); err != nil {
		firstErr = err
	}
	if err := d.read.Close(); err != nil && firstErr == nil {
		firstErr = err
	}
	return firstErr
}

// Checkpoint runs a WAL checkpoint, used before a backup or on shutdown.
func (d *DB) Checkpoint(ctx context.Context) error {
	return d.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, "PRAGMA wal_checkpoint(TRUNCATE)")
		return err
	})
}

// NowMillis is the single time source for every stored timestamp.
func NowMillis() int64 { return time.Now().UnixMilli() }
