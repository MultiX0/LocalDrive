// Package settings owns the single server_settings row: the handful of
// everyday preferences that are editable at runtime rather than through a
// redeploy.
package settings

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"sync"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// Defaults seeds the row the first time the server starts.
type Defaults struct {
	ServerName            string
	RequireDeviceApproval bool
	EnableLANDiscovery    bool
	AllowSelfRegistration bool
	TrashRetentionDays    int
	VersionRetentionCount int
	VersionRetentionDays  int
}

// Service reads and writes server settings, caching the row in memory since
// it is read on nearly every request and written rarely.
type Service struct {
	database *db.DB
	mu       sync.RWMutex
	cached   models.ServerSettings
	watchers []func(models.ServerSettings)
}

// New loads or seeds the settings row.
func New(ctx context.Context, database *db.DB, def Defaults) (*Service, error) {
	s := &Service{database: database}
	if err := s.ensure(ctx, def); err != nil {
		return nil, err
	}
	if err := s.reload(ctx); err != nil {
		return nil, err
	}
	return s, nil
}

func (s *Service) ensure(ctx context.Context, def Defaults) error {
	var count int
	err := s.database.Read().QueryRowContext(ctx, `SELECT COUNT(*) FROM server_settings WHERE id = 1`).Scan(&count)
	if err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	name := strings.TrimSpace(def.ServerName)
	if name == "" {
		name = "Local Drive"
	}
	now := db.NowMillis()
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `
			INSERT INTO server_settings
			  (id, server_id, server_name, require_device_approval, enable_lan_discovery,
			   allow_self_registration, trash_retention_days, version_retention_count,
			   version_retention_days, setup_completed_at, created_at, updated_at)
			VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)
			ON CONFLICT (id) DO NOTHING`,
			db.NewID(), name,
			boolToInt(def.RequireDeviceApproval), boolToInt(def.EnableLANDiscovery),
			boolToInt(def.AllowSelfRegistration),
			def.TrashRetentionDays, def.VersionRetentionCount, def.VersionRetentionDays,
			now, now)
		return err
	})
}

func (s *Service) reload(ctx context.Context) error {
	var (
		out                                             models.ServerSettings
		requireApproval, lanDiscovery, selfRegistration int
		setupCompleted                                  sql.NullInt64
	)
	err := s.database.Read().QueryRowContext(ctx, `
		SELECT server_id, server_name, require_device_approval, enable_lan_discovery,
		       allow_self_registration, trash_retention_days, version_retention_count,
		       version_retention_days, setup_completed_at, created_at, updated_at
		FROM server_settings WHERE id = 1`).Scan(
		&out.ServerID, &out.ServerName, &requireApproval, &lanDiscovery, &selfRegistration,
		&out.TrashRetentionDays, &out.VersionRetentionCount, &out.VersionRetentionDays,
		&setupCompleted, &out.CreatedAt, &out.UpdatedAt)
	if err != nil {
		return err
	}
	out.RequireDeviceApproval = requireApproval != 0
	out.EnableLANDiscovery = lanDiscovery != 0
	out.AllowSelfRegistration = selfRegistration != 0
	out.SetupCompletedAt = db.Int64OrZero(setupCompleted)

	s.mu.Lock()
	s.cached = out
	watchers := append([]func(models.ServerSettings){}, s.watchers...)
	s.mu.Unlock()
	for _, w := range watchers {
		w(out)
	}
	return nil
}

// Get returns the current settings.
func (s *Service) Get() models.ServerSettings {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.cached
}

// Watch registers a callback fired whenever settings change, used by the LAN
// discovery bridge so an admin toggling the setting takes effect immediately.
func (s *Service) Watch(fn func(models.ServerSettings)) {
	s.mu.Lock()
	s.watchers = append(s.watchers, fn)
	current := s.cached
	s.mu.Unlock()
	fn(current)
}

// Update is a partial update; nil fields are left alone.
type Update struct {
	ServerName            *string
	RequireDeviceApproval *bool
	EnableLANDiscovery    *bool
	AllowSelfRegistration *bool
	TrashRetentionDays    *int
	VersionRetentionCount *int
	VersionRetentionDays  *int
}

// ErrInvalid marks a rejected settings update.
var ErrInvalid = errors.New("settings: invalid value")

// Apply writes a partial update and refreshes the cache.
func (s *Service) Apply(ctx context.Context, u Update) (models.ServerSettings, error) {
	sets := []string{"updated_at = ?"}
	args := []any{db.NowMillis()}

	if u.ServerName != nil {
		name := strings.TrimSpace(*u.ServerName)
		if name == "" || len(name) > 64 {
			return models.ServerSettings{}, ErrInvalid
		}
		sets = append(sets, "server_name = ?")
		args = append(args, name)
	}
	if u.RequireDeviceApproval != nil {
		sets = append(sets, "require_device_approval = ?")
		args = append(args, boolToInt(*u.RequireDeviceApproval))
	}
	if u.EnableLANDiscovery != nil {
		sets = append(sets, "enable_lan_discovery = ?")
		args = append(args, boolToInt(*u.EnableLANDiscovery))
	}
	if u.AllowSelfRegistration != nil {
		sets = append(sets, "allow_self_registration = ?")
		args = append(args, boolToInt(*u.AllowSelfRegistration))
	}
	if u.TrashRetentionDays != nil {
		if *u.TrashRetentionDays < 1 || *u.TrashRetentionDays > 3650 {
			return models.ServerSettings{}, ErrInvalid
		}
		sets = append(sets, "trash_retention_days = ?")
		args = append(args, *u.TrashRetentionDays)
	}
	if u.VersionRetentionCount != nil {
		if *u.VersionRetentionCount < 1 || *u.VersionRetentionCount > 1000 {
			return models.ServerSettings{}, ErrInvalid
		}
		sets = append(sets, "version_retention_count = ?")
		args = append(args, *u.VersionRetentionCount)
	}
	if u.VersionRetentionDays != nil {
		if *u.VersionRetentionDays < 1 || *u.VersionRetentionDays > 3650 {
			return models.ServerSettings{}, ErrInvalid
		}
		sets = append(sets, "version_retention_days = ?")
		args = append(args, *u.VersionRetentionDays)
	}

	query := "UPDATE server_settings SET " + strings.Join(sets, ", ") + " WHERE id = 1"
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, query, args...)
		return err
	})
	if err != nil {
		return models.ServerSettings{}, err
	}
	if err := s.reload(ctx); err != nil {
		return models.ServerSettings{}, err
	}
	return s.Get(), nil
}

// MarkSetupComplete stamps the row the first time an admin account exists.
func (s *Service) MarkSetupComplete(ctx context.Context, tx *sql.Tx) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE server_settings SET setup_completed_at = ?, updated_at = ? WHERE id = 1 AND setup_completed_at IS NULL`,
		db.NowMillis(), db.NowMillis())
	return err
}

// Refresh re-reads the row, used after a transaction that changed it.
func (s *Service) Refresh(ctx context.Context) error { return s.reload(ctx) }

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
