package auth

import (
	"context"
	"database/sql"
	"errors"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

const sessionColumns = `id, user_id, device_name, platform, status, refresh_token_hash, ip,
	user_agent, created_at, last_seen_at, expires_at, approved_at, approved_by, revoked_at`

func scanSession(row userScanner) (models.Session, error) {
	var (
		s                                models.Session
		refreshHash, approvedBy          sql.NullString
		expiresAt, approvedAt, revokedAt sql.NullInt64
		status                           string
	)
	err := row.Scan(&s.ID, &s.UserID, &s.DeviceName, &s.Platform, &status, &refreshHash, &s.IP,
		&s.UserAgent, &s.CreatedAt, &s.LastSeenAt, &expiresAt, &approvedAt, &approvedBy, &revokedAt)
	if err != nil {
		return models.Session{}, err
	}
	s.Status = models.SessionStatus(status)
	s.RefreshTokenHash = db.StringOrEmpty(refreshHash)
	s.ApprovedBy = db.StringOrEmpty(approvedBy)
	s.ExpiresAt = db.Int64OrZero(expiresAt)
	s.ApprovedAt = db.Int64OrZero(approvedAt)
	s.RevokedAt = db.Int64OrZero(revokedAt)
	return s, nil
}

func (s *Service) sessionByID(ctx context.Context, id string) (models.Session, error) {
	row := s.database.Read().QueryRowContext(ctx, `SELECT `+sessionColumns+` FROM sessions WHERE id = ?`, id)
	sess, err := scanSession(row)
	if errors.Is(err, sql.ErrNoRows) {
		return models.Session{}, ErrNotFound
	}
	return sess, err
}

// ListSessions returns every device on the caller's account.
func (s *Service) ListSessions(ctx context.Context, userID string) ([]models.Session, error) {
	rows, err := s.database.Read().QueryContext(ctx,
		`SELECT `+sessionColumns+` FROM sessions WHERE user_id = ? AND status != 'denied'
		 ORDER BY last_seen_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Session
	for rows.Next() {
		sess, err := scanSession(rows)
		if err != nil {
			return nil, err
		}
		sess.RefreshTokenHash = ""
		out = append(out, sess)
	}
	return out, rows.Err()
}

// ListPendingDevices returns devices waiting for approval. A member sees only
// their own; an admin sees every account's, as the stuck-user fallback.
func (s *Service) ListPendingDevices(ctx context.Context, userID string, adminWide bool) ([]models.Session, error) {
	query := `SELECT ` + sessionColumns + ` FROM sessions WHERE status = 'pending'`
	var args []any
	if !adminWide {
		query += ` AND user_id = ?`
		args = append(args, userID)
	}
	query += ` ORDER BY created_at DESC`
	rows, err := s.database.Read().QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Session
	for rows.Next() {
		sess, err := scanSession(rows)
		if err != nil {
			return nil, err
		}
		sess.RefreshTokenHash = ""
		out = append(out, sess)
	}
	return out, rows.Err()
}

// ApproveDevice lets a pending device in. Self-service for a device on your
// own account, with an admin able to step in for anyone who is stuck.
func (s *Service) ApproveDevice(ctx context.Context, actor models.User, sessionID, ip string) error {
	sess, err := s.sessionByID(ctx, sessionID)
	if err != nil {
		return err
	}
	if sess.UserID != actor.ID && !actor.IsAdmin() {
		return ErrForbidden
	}
	if sess.Status != models.SessionPending {
		return ErrSessionInvalid
	}
	now := db.NowMillis()
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx, `
			UPDATE sessions SET status = 'active', approved_at = ?, approved_by = ?, last_seen_at = ?
			WHERE id = ? AND status = 'pending'`, now, actor.ID, now, sessionID)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrSessionInvalid
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: actor.ID, Action: audit.ActionDeviceApproved, IP: ip,
			Metadata: map[string]any{"session": sessionID, "account": sess.UserID, "device": sess.DeviceName},
		})
	})
	if err != nil {
		return err
	}
	s.hub.Publish(ws.NewEvent(ws.EventDeviceApproved, now, map[string]any{
		"session_id": sessionID, "device_name": sess.DeviceName,
	}), sess.UserID)
	return nil
}

// DenyDevice discards a pending login. Nothing about it is retained beyond
// the audit entry.
func (s *Service) DenyDevice(ctx context.Context, actor models.User, sessionID, ip string) error {
	sess, err := s.sessionByID(ctx, sessionID)
	if err != nil {
		return err
	}
	if sess.UserID != actor.ID && !actor.IsAdmin() {
		return ErrForbidden
	}
	if sess.Status != models.SessionPending {
		return ErrSessionInvalid
	}
	now := db.NowMillis()
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `
			UPDATE sessions SET status = 'denied', revoked_at = ?, refresh_token_hash = NULL
			WHERE id = ? AND status = 'pending'`, now, sessionID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: actor.ID, Action: audit.ActionDeviceDenied, IP: ip,
			Metadata: map[string]any{"session": sessionID, "account": sess.UserID},
		})
	})
	if err != nil {
		return err
	}
	s.hub.Publish(ws.NewEvent(ws.EventDeviceDenied, now, map[string]any{
		"session_id": sessionID,
	}), sess.UserID)
	return nil
}

// RevokeSession signs one device out. A member may revoke their own devices;
// an admin may revoke anyone's.
func (s *Service) RevokeSession(ctx context.Context, actor models.User, sessionID, ip string) error {
	sess, err := s.sessionByID(ctx, sessionID)
	if err != nil {
		return err
	}
	if sess.UserID != actor.ID && !actor.IsAdmin() {
		return ErrForbidden
	}
	now := db.NowMillis()
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `
			UPDATE sessions SET status = 'revoked', revoked_at = ?, refresh_token_hash = NULL WHERE id = ?`,
			now, sessionID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: actor.ID, Action: audit.ActionDeviceRevoked, IP: ip,
			Metadata: map[string]any{"session": sessionID, "account": sess.UserID},
		})
	})
	if err != nil {
		return err
	}
	s.hub.Publish(ws.NewEvent(ws.EventSessionRevoked, now, map[string]any{
		"session_id": sessionID,
	}), sess.UserID)
	return nil
}

// PurgeStaleSessions drops revoked and expired rows, keeping the Devices
// screen honest without an unbounded table behind it.
func (s *Service) PurgeStaleSessions(ctx context.Context, olderThanMillis int64) error {
	cutoff := db.NowMillis() - olderThanMillis
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`DELETE FROM sessions WHERE status IN ('revoked','denied') AND COALESCE(revoked_at, created_at) < ?`,
			cutoff); err != nil {
			return err
		}
		_, err := tx.ExecContext(ctx,
			`UPDATE sessions SET status = 'revoked', revoked_at = ?, refresh_token_hash = NULL
			 WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at < ?`,
			db.NowMillis(), db.NowMillis())
		return err
	})
}
