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
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

// ErrClosed is returned once the writer has been shut down.
var ErrClosed = errors.New("db: closed")

// checkpointTimeout bounds the shutdown checkpoint. Stopping promptly matters
// more than a collapsed log, and systemd will not wait forever either.
const checkpointTimeout = 10 * time.Second

// DB holds both connection pools and the writer queue.
type DB struct {
	read   *sql.DB
	write  *sql.DB
	jobs   chan writeJob
	done   chan struct{}
	closed chan struct{}
	log    *slog.Logger
	path   string

	// gate is held for reading while a write is being queued and exclusively
	// while shutting down, so the two can never overlap.
	gate sync.RWMutex
	shut bool
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
//
// The queue is never closed. A select that offers a send on a closed channel
// panics when it happens to pick that case, so closing it made any write
// racing with shutdown a crash rather than an error: a request in flight while
// the server stopped could take the process down with it.
func (d *DB) Write(ctx context.Context, fn func(context.Context, *sql.Tx) error) error {
	res := make(chan error, 1)
	job := writeJob{ctx: ctx, fn: fn, res: res}

	// held across the send, so shutdown cannot begin midway through one: once
	// Close takes this exclusively, every job that will ever be queued already
	// is, and the writer can drain the rest and know it is finished
	d.gate.RLock()
	if d.shut {
		d.gate.RUnlock()
		return ErrClosed
	}
	select {
	case d.jobs <- job:
		d.gate.RUnlock()
	case <-ctx.Done():
		d.gate.RUnlock()
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
	for {
		select {
		case job := <-d.jobs:
			job.res <- d.runJob(job)
		case <-d.done:
			// nothing more can arrive, so whatever is still queued is the last
			// of it and every caller waiting on an answer gets one
			for {
				select {
				case job := <-d.jobs:
					job.res <- d.runJob(job)
				default:
					return
				}
			}
		}
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

// Close drains outstanding writes, collapses the write-ahead log, and shuts
// both pools down.
//
// The order is the whole point. A TRUNCATE checkpoint needs the database to
// itself, and every connection sitting idle in the read pool still holds a WAL
// read lock, so checkpointing while they are open reports "database table is
// locked" and leaves the log behind. Closing the readers first is what makes a
// shutdown clean rather than merely quiet.
func (d *DB) Close() error {
	// taken exclusively, so this waits for any write already being queued and
	// shuts the door on the next one
	d.gate.Lock()
	if d.shut {
		d.gate.Unlock()
		return nil
	}
	d.shut = true
	close(d.done)
	d.gate.Unlock()
	<-d.closed

	var firstErr error
	// readers first: their locks are exactly what the checkpoint would wait on
	if err := d.read.Close(); err != nil {
		firstErr = err
	}

	ctx, cancel := context.WithTimeout(context.Background(), checkpointTimeout)
	defer cancel()
	if err := d.Checkpoint(ctx); err != nil {
		// a log left behind costs a slower next start and nothing else, so it
		// is worth saying and never worth failing on
		d.log.Warn("could not collapse the write-ahead log", "error", err)
	}

	if err := d.write.Close(); err != nil && firstErr == nil {
		firstErr = err
	}
	return firstErr
}

// Checkpoint folds the write-ahead log back into the database file, so a copy
// taken afterwards is the whole story rather than most of it.
//
// It runs on the write pool directly and not through the writer queue: a
// checkpoint cannot happen inside a transaction, and every job on that queue is
// wrapped in one. Asking for it there returned "database table is locked" every
// time, which is what shutdown reported on every stop for as long as this
// existed. The pool holds a single connection, so this still waits for any
// write in flight instead of racing it.
func (d *DB) Checkpoint(ctx context.Context) error {
	if _, err := d.write.ExecContext(ctx, "PRAGMA wal_checkpoint(TRUNCATE)"); err != nil {
		return fmt.Errorf("db: checkpoint: %w", err)
	}
	return nil
}

// NowMillis is the single time source for every stored timestamp.
func NowMillis() int64 { return time.Now().UnixMilli() }
