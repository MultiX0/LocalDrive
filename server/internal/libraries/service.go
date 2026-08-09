// Package libraries owns storage roots: registering one, reading its live
// free space, marking it offline when its device disappears, and bringing it
// back when the device returns.
package libraries

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/storage"
)

// Errors returned by this package.
var (
	ErrNotFound  = errors.New("libraries: library not found")
	ErrOffline   = errors.New("libraries: library is offline, its drive is not connected")
	ErrDuplicate = errors.New("libraries: a library is already registered at that path")
	ErrLastOne   = errors.New("libraries: cannot remove the only library")
	ErrInvalid   = errors.New("libraries: invalid library")
)

// Service reads and writes the libraries table and keeps a small cache so a
// per-request root lookup is not a query every time.
type Service struct {
	database *db.DB
	store    *storage.Store
	log      *slog.Logger

	mu    sync.RWMutex
	cache map[string]models.Library
	def   string

	onChange []func()
}

// New loads the library set into memory.
func New(ctx context.Context, database *db.DB, store *storage.Store, log *slog.Logger) (*Service, error) {
	if log == nil {
		log = slog.Default()
	}
	s := &Service{database: database, store: store, log: log, cache: map[string]models.Library{}}
	if err := s.Reload(ctx); err != nil {
		return nil, err
	}
	return s, nil
}

// OnChange registers a callback fired after any library mutation.
func (s *Service) OnChange(fn func()) {
	s.mu.Lock()
	s.onChange = append(s.onChange, fn)
	s.mu.Unlock()
}

func (s *Service) notify() {
	s.mu.RLock()
	fns := append([]func(){}, s.onChange...)
	s.mu.RUnlock()
	for _, fn := range fns {
		fn()
	}
}

// Reload refreshes the in-memory view from the database.
func (s *Service) Reload(ctx context.Context) error {
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT id, name, root_path, kind, is_external, is_default, status, device_id,
		       members_json, bytes_used, created_at, updated_at
		FROM libraries ORDER BY created_at`)
	if err != nil {
		return err
	}
	defer rows.Close()

	next := map[string]models.Library{}
	def := ""
	for rows.Next() {
		lib, err := scanLibrary(rows)
		if err != nil {
			return err
		}
		next[lib.ID] = lib
		if lib.IsDefault {
			def = lib.ID
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	s.mu.Lock()
	s.cache = next
	s.def = def
	s.mu.Unlock()
	return nil
}

type scanner interface {
	Scan(dest ...any) error
}

func scanLibrary(row scanner) (models.Library, error) {
	var (
		lib                   models.Library
		isExternal, isDefault int
		deviceID, membersJSON sql.NullString
		kind                  string
	)
	if err := row.Scan(&lib.ID, &lib.Name, &lib.RootPath, &kind, &isExternal, &isDefault,
		&lib.Status, &deviceID, &membersJSON, &lib.BytesUsed, &lib.CreatedAt, &lib.UpdatedAt); err != nil {
		return models.Library{}, err
	}
	lib.Kind = models.LibraryKind(kind)
	lib.IsExternal = isExternal != 0
	lib.IsDefault = isDefault != 0
	lib.DeviceID = db.StringOrEmpty(deviceID)
	if membersJSON.Valid && membersJSON.String != "" {
		_ = json.Unmarshal([]byte(membersJSON.String), &lib.Members)
	}
	return lib, nil
}

// Get returns one library from cache.
func (s *Service) Get(id string) (models.Library, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	lib, ok := s.cache[id]
	if !ok {
		return models.Library{}, ErrNotFound
	}
	return lib, nil
}

// Root returns a library's filesystem root, refusing if it is offline. Every
// read and write path goes through here so an unplugged drive produces one
// clear error instead of failing in unrelated ways later.
func (s *Service) Root(id string) (string, error) {
	lib, err := s.Get(id)
	if err != nil {
		return "", err
	}
	if !lib.Online() {
		return "", fmt.Errorf("%w: %s", ErrOffline, lib.Name)
	}
	return lib.RootPath, nil
}

// RootAllowOffline returns a root even for an offline library, used by the
// probe that decides whether it has come back.
func (s *Service) RootAllowOffline(id string) (string, error) {
	lib, err := s.Get(id)
	if err != nil {
		return "", err
	}
	return lib.RootPath, nil
}

// Default returns the library new top-level content goes into.
func (s *Service) Default() (models.Library, error) {
	s.mu.RLock()
	def := s.def
	s.mu.RUnlock()
	if def != "" {
		if lib, err := s.Get(def); err == nil && lib.Online() {
			return lib, nil
		}
	}
	// fall back to the first online library so an unplugged default never
	// blocks an upload that had somewhere else to go
	s.mu.RLock()
	defer s.mu.RUnlock()
	for _, lib := range s.cache {
		if lib.Online() {
			return lib, nil
		}
	}
	return models.Library{}, ErrNotFound
}

// List returns every library with live disk stats filled in. An offline
// library reports its last known bytes_used and no free/total rather than
// failing the whole request.
func (s *Service) List(ctx context.Context) ([]models.Library, error) {
	if err := s.Reload(ctx); err != nil {
		return nil, err
	}
	s.mu.RLock()
	out := make([]models.Library, 0, len(s.cache))
	for _, lib := range s.cache {
		out = append(out, lib)
	}
	s.mu.RUnlock()

	for i := range out {
		if !out[i].Online() {
			continue
		}
		total, free, err := s.store.FreeSpace(out[i].RootPath)
		if err != nil {
			s.log.Debug("disk stats unavailable", "library", out[i].Name, "error", err)
			continue
		}
		out[i].TotalBytes = total
		out[i].FreeBytes = free
		out[i].StatsKnown = true
	}
	sortLibraries(out)
	return out, nil
}

func sortLibraries(list []models.Library) {
	for i := 1; i < len(list); i++ {
		for j := i; j > 0; j-- {
			a, b := list[j-1], list[j]
			if less(b, a) {
				list[j-1], list[j] = b, a
				continue
			}
			break
		}
	}
}

func less(a, b models.Library) bool {
	if a.IsDefault != b.IsDefault {
		return a.IsDefault
	}
	if a.CreatedAt != b.CreatedAt {
		return a.CreatedAt < b.CreatedAt
	}
	return a.ID < b.ID
}

// RegisterOptions describes a library about to be created.
type RegisterOptions struct {
	Name        string
	RootPath    string
	Kind        models.LibraryKind
	IsExternal  bool
	MakeDefault bool
	Members     []string
}

// Register prepares a root directory and records it as a library.
func (s *Service) Register(ctx context.Context, opts RegisterOptions) (models.Library, error) {
	name := strings.TrimSpace(opts.Name)
	if name == "" || len(name) > 64 {
		return models.Library{}, fmt.Errorf("%w: name", ErrInvalid)
	}
	if strings.TrimSpace(opts.RootPath) == "" {
		return models.Library{}, fmt.Errorf("%w: root path", ErrInvalid)
	}
	switch opts.Kind {
	case models.LibraryInternal, models.LibraryExternal, models.LibraryNetwork, models.LibraryPooled:
	default:
		return models.Library{}, fmt.Errorf("%w: kind", ErrInvalid)
	}
	if err := s.store.Prepare(opts.RootPath); err != nil {
		return models.Library{}, err
	}
	deviceID, err := s.store.DeviceIdentity(opts.RootPath)
	if err != nil {
		s.log.Warn("device identity unavailable, offline detection disabled for this library",
			"path", opts.RootPath, "error", err)
	}
	var members sql.NullString
	if len(opts.Members) > 0 {
		if encoded, err := json.Marshal(opts.Members); err == nil {
			members = db.NullString(string(encoded))
		}
	}

	id := db.NewID()
	now := db.NowMillis()
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		var existing int
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM libraries WHERE root_path = ?`, opts.RootPath).Scan(&existing); err != nil {
			return err
		}
		if existing > 0 {
			return ErrDuplicate
		}
		var total int
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM libraries`).Scan(&total); err != nil {
			return err
		}
		makeDefault := opts.MakeDefault || total == 0
		if makeDefault {
			if _, err := tx.ExecContext(ctx, `UPDATE libraries SET is_default = 0, updated_at = ?`, now); err != nil {
				return err
			}
		}
		_, err := tx.ExecContext(ctx, `
			INSERT INTO libraries (id, name, root_path, kind, is_external, is_default, status,
			                       device_id, members_json, bytes_used, created_at, updated_at)
			VALUES (?, ?, ?, ?, ?, ?, 'online', ?, ?, 0, ?, ?)`,
			id, name, opts.RootPath, string(opts.Kind), boolInt(opts.IsExternal), boolInt(makeDefault),
			db.NullString(deviceID), members, now, now)
		return err
	})
	if err != nil {
		return models.Library{}, err
	}
	if err := s.Reload(ctx); err != nil {
		return models.Library{}, err
	}
	s.notify()
	return s.Get(id)
}

// SetDefault marks one library as the target for new top-level content.
func (s *Service) SetDefault(ctx context.Context, id string) error {
	lib, err := s.Get(id)
	if err != nil {
		return err
	}
	if !lib.Online() {
		return ErrOffline
	}
	now := db.NowMillis()
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `UPDATE libraries SET is_default = 0, updated_at = ?`, now); err != nil {
			return err
		}
		res, err := tx.ExecContext(ctx, `UPDATE libraries SET is_default = 1, updated_at = ? WHERE id = ?`, now, id)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		return nil
	})
	if err != nil {
		return err
	}
	if err := s.Reload(ctx); err != nil {
		return err
	}
	s.notify()
	return nil
}

// Rename changes a library's display name.
func (s *Service) Rename(ctx context.Context, id, name string) error {
	name = strings.TrimSpace(name)
	if name == "" || len(name) > 64 {
		return fmt.Errorf("%w: name", ErrInvalid)
	}
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx, `UPDATE libraries SET name = ?, updated_at = ? WHERE id = ?`,
			name, db.NowMillis(), id)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		return nil
	})
	if err != nil {
		return err
	}
	if err := s.Reload(ctx); err != nil {
		return err
	}
	s.notify()
	return nil
}

// SetStatus flips a library between online and offline.
func (s *Service) SetStatus(ctx context.Context, id, status string) error {
	if status != models.LibraryOnline && status != models.LibraryOffline {
		return fmt.Errorf("%w: status", ErrInvalid)
	}
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `UPDATE libraries SET status = ?, updated_at = ? WHERE id = ?`,
			status, db.NowMillis(), id)
		return err
	})
	if err != nil {
		return err
	}
	if err := s.Reload(ctx); err != nil {
		return err
	}
	s.notify()
	return nil
}

// Remove deletes a library registration. Refuses while it still holds nodes,
// since dropping it would orphan them.
func (s *Service) Remove(ctx context.Context, id string) error {
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		var nodeCount, libCount int
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM nodes WHERE library_id = ? AND deleted_at IS NULL`, id).Scan(&nodeCount); err != nil {
			return err
		}
		if nodeCount > 0 {
			return fmt.Errorf("%w: %d items still live here", ErrInvalid, nodeCount)
		}
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM libraries`).Scan(&libCount); err != nil {
			return err
		}
		if libCount <= 1 {
			return ErrLastOne
		}
		_, err := tx.ExecContext(ctx, `DELETE FROM libraries WHERE id = ?`, id)
		return err
	})
}

// AddBytesTx adjusts a library's running usage counter inside a caller's
// transaction, so usage and content commit together.
func AddBytesTx(ctx context.Context, tx *sql.Tx, libraryID string, delta int64) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE libraries SET bytes_used = MAX(0, bytes_used + ?), updated_at = ? WHERE id = ?`,
		delta, db.NowMillis(), libraryID)
	return err
}

// Probe checks every library's backing device and flips status when it
// changed. Returns the ids whose status moved, for the audit log and the
// websocket event.
func (s *Service) Probe(ctx context.Context) (wentOffline, cameOnline []string, err error) {
	if err := s.Reload(ctx); err != nil {
		return nil, nil, err
	}
	s.mu.RLock()
	current := make([]models.Library, 0, len(s.cache))
	for _, lib := range s.cache {
		current = append(current, lib)
	}
	s.mu.RUnlock()

	for _, lib := range current {
		present := true
		if _, same, err := s.store.SameDevice(lib.RootPath, lib.DeviceID); err != nil || !same {
			present = false
		}
		switch {
		case present && lib.Status == models.LibraryOffline:
			if err := s.SetStatus(ctx, lib.ID, models.LibraryOnline); err == nil {
				cameOnline = append(cameOnline, lib.ID)
			}
		case !present && lib.Status == models.LibraryOnline:
			if err := s.SetStatus(ctx, lib.ID, models.LibraryOffline); err == nil {
				wentOffline = append(wentOffline, lib.ID)
			}
		}
	}
	return wentOffline, cameOnline, nil
}

// RecalculateUsage rebuilds bytes_used from the nodes table. A correctness
// pass, not the hot path; normal writes keep the counter current.
func (s *Service) RecalculateUsage(ctx context.Context) error {
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `
			UPDATE libraries SET bytes_used = COALESCE((
				SELECT SUM(size_bytes) FROM nodes
				WHERE nodes.library_id = libraries.id
				  AND nodes.type = 'file' AND nodes.deleted_at IS NULL
			), 0), updated_at = ?`, db.NowMillis())
		return err
	})
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
