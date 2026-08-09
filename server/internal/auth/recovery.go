package auth

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
)

// RecoveryMarkerName is the file the setup CLI writes into the data directory
// to reset a locked-out admin. The CLI never touches the SQLite file itself;
// the server stays the only writer to its own database.
const RecoveryMarkerName = ".localdrive-reset-admin"

// RecoveryMarker is the marker file's contents.
type RecoveryMarker struct {
	Password  string `json:"password"`
	Username  string `json:"username,omitempty"`
	CreatedAt int64  `json:"created_at"`
}

// ConsumeRecoveryMarker runs before the server serves any request. If the
// marker is present it resets the named admin's password, deletes the marker,
// and writes an audit entry that a recovery reset happened.
func (s *Service) ConsumeRecoveryMarker(ctx context.Context, dataDir string, log *slog.Logger) error {
	if log == nil {
		log = slog.Default()
	}
	path := filepath.Join(dataDir, RecoveryMarkerName)
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("auth: read recovery marker: %w", err)
	}
	// remove it first, so a marker that somehow fails to apply cannot loop
	// the server into resetting the password on every restart
	defer func() {
		if rmErr := os.Remove(path); rmErr != nil && !os.IsNotExist(rmErr) {
			log.Error("could not remove recovery marker, remove it by hand", "path", path, "error", rmErr)
		}
	}()

	var marker RecoveryMarker
	if err := json.Unmarshal(raw, &marker); err != nil {
		return fmt.Errorf("auth: recovery marker is not valid json: %w", err)
	}
	if err := ValidatePassword(marker.Password); err != nil {
		return fmt.Errorf("auth: recovery marker password rejected: %w", err)
	}
	hash, err := s.hasher.Hash(marker.Password)
	if err != nil {
		return err
	}

	var targetID, targetName string
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		query := `SELECT id, username FROM users WHERE role = 'admin' ORDER BY created_at LIMIT 1`
		args := []any{}
		if u := strings.TrimSpace(marker.Username); u != "" {
			query = `SELECT id, username FROM users WHERE lower(username) = lower(?) LIMIT 1`
			args = append(args, u)
		}
		err := tx.QueryRowContext(ctx, query, args...).Scan(&targetID, &targetName)
		if errors.Is(err, sql.ErrNoRows) {
			return errors.New("auth: no account to reset, the server has not been set up yet")
		}
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE users SET password_hash = ?, must_change_password = 1, disabled_at = NULL, updated_at = ?
			WHERE id = ?`, hash, db.NowMillis(), targetID); err != nil {
			return err
		}
		// every existing session on that account ends with the reset
		if _, err := tx.ExecContext(ctx, `
			UPDATE sessions SET status = 'revoked', revoked_at = ?, refresh_token_hash = NULL
			WHERE user_id = ?`, db.NowMillis(), targetID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: targetID, Action: audit.ActionRecoveryReset,
			Metadata: map[string]any{"username": targetName, "source": "setup cli marker"},
		})
	})
	if err != nil {
		return err
	}
	log.Warn("admin password reset from a recovery marker, it must be changed on next sign in",
		"username", targetName)
	return nil
}
