// Package audit writes the activity log. Every security-relevant action goes
// through here so the trail is complete rather than assembled from logs.
package audit

import (
	"context"
	"database/sql"
	"encoding/json"
	"log/slog"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// Action names, one constant per recorded event.
const (
	ActionLogin             = "auth.login"
	ActionLoginFailed       = "auth.login_failed"
	ActionLogout            = "auth.logout"
	ActionPasswordChanged   = "auth.password_changed"
	ActionPasswordReset     = "auth.password_reset"
	ActionRecoveryReset     = "auth.recovery_reset"
	ActionTOTPEnabled       = "auth.totp_enabled"
	ActionTOTPDisabled      = "auth.totp_disabled"
	ActionSetupCompleted    = "server.setup_completed"
	ActionSettingsChanged   = "server.settings_changed"
	ActionUserCreated       = "user.created"
	ActionUserRoleChanged   = "user.role_changed"
	ActionUserDisabled      = "user.disabled"
	ActionInviteCreated     = "invite.created"
	ActionInviteRevoked     = "invite.revoked"
	ActionInviteRedeemed    = "invite.redeemed"
	ActionDevicePending     = "device.pending"
	ActionDeviceApproved    = "device.approved"
	ActionDeviceDenied      = "device.denied"
	ActionDeviceRevoked     = "device.revoked"
	ActionNodeCreated       = "node.created"
	ActionNodeRenamed       = "node.renamed"
	ActionNodeMoved         = "node.moved"
	ActionNodeRecolored     = "node.recolored"
	ActionNodeTrashed       = "node.trashed"
	ActionNodeRestored      = "node.restored"
	ActionNodeDeleted       = "node.permanently_deleted"
	ActionNodeUploaded      = "node.uploaded"
	ActionNodeDownloaded    = "node.downloaded"
	ActionVersionRestored   = "node.version_restored"
	ActionShareCreated      = "share.created"
	ActionShareUpdated      = "share.updated"
	ActionShareRevoked      = "share.revoked"
	ActionShareExpired      = "share.expired"
	ActionShareAccessed     = "share.accessed"
	ActionPermissionGranted = "permission.granted"
	ActionPermissionRevoked = "permission.revoked"
	ActionLibraryRegistered = "library.registered"
	ActionLibraryDefaultSet = "library.default_set"
	ActionDriveMounted      = "drive.mounted"
	ActionDriveEjected      = "drive.ejected"
	ActionDriveFormatted    = "drive.formatted"
	ActionDrivePooled       = "drive.pooled"
)

// Entry is one pending audit record.
type Entry struct {
	UserID   string
	NodeID   string
	Action   string
	IP       string
	Metadata map[string]any
}

// Logger writes entries. Failures are logged, never returned into a request
// path, so an audit hiccup cannot take down the operation it describes.
type Logger struct {
	database *db.DB
	log      *slog.Logger
}

// New returns a Logger.
func New(database *db.DB, log *slog.Logger) *Logger {
	if log == nil {
		log = slog.Default()
	}
	return &Logger{database: database, log: log}
}

// Record writes one entry on the writer goroutine.
func (l *Logger) Record(ctx context.Context, e Entry) {
	if err := l.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		return l.RecordTx(ctx, tx, e)
	}); err != nil {
		l.log.Error("audit write failed", "action", e.Action, "error", err)
	}
}

// RecordTx writes one entry inside a caller's transaction, which is how an
// action and its audit row commit together.
func (l *Logger) RecordTx(ctx context.Context, tx *sql.Tx, e Entry) error {
	meta := "{}"
	if len(e.Metadata) > 0 {
		if encoded, err := json.Marshal(e.Metadata); err == nil {
			meta = string(encoded)
		}
	}
	_, err := tx.ExecContext(ctx, `
		INSERT INTO activity_log (id, user_id, node_id, action, metadata_json, ip, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)`,
		db.NewID(), db.NullString(e.UserID), db.NullString(e.NodeID),
		e.Action, meta, e.IP, db.NowMillis())
	return err
}

// ListOptions filters an activity query.
type ListOptions struct {
	UserID   string
	NodeID   string
	Action   string
	Limit    int
	Before   int64
	AdminAll bool
}

// List returns activity rows newest first. A member only ever sees their own
// rows; the admin-wide view is gated by the caller.
func (l *Logger) List(ctx context.Context, opts ListOptions) ([]models.Activity, error) {
	if opts.Limit <= 0 || opts.Limit > 200 {
		opts.Limit = 50
	}
	query := `SELECT id, user_id, node_id, action, metadata_json, ip, created_at FROM activity_log WHERE 1 = 1`
	var args []any
	if !opts.AdminAll {
		query += ` AND user_id = ?`
		args = append(args, opts.UserID)
	} else if opts.UserID != "" {
		query += ` AND user_id = ?`
		args = append(args, opts.UserID)
	}
	if opts.NodeID != "" {
		query += ` AND node_id = ?`
		args = append(args, opts.NodeID)
	}
	if opts.Action != "" {
		query += ` AND action = ?`
		args = append(args, opts.Action)
	}
	if opts.Before > 0 {
		query += ` AND created_at < ?`
		args = append(args, opts.Before)
	}
	query += ` ORDER BY created_at DESC LIMIT ?`
	args = append(args, opts.Limit)

	rows, err := l.database.Read().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Activity
	for rows.Next() {
		var (
			a              models.Activity
			userID, nodeID sql.NullString
			meta           string
		)
		if err := rows.Scan(&a.ID, &userID, &nodeID, &a.Action, &meta, &a.IP, &a.CreatedAt); err != nil {
			return nil, err
		}
		a.UserID = db.StringOrEmpty(userID)
		a.NodeID = db.StringOrEmpty(nodeID)
		a.Metadata = map[string]any{}
		_ = json.Unmarshal([]byte(meta), &a.Metadata)
		out = append(out, a)
	}
	return out, rows.Err()
}
