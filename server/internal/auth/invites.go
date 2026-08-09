package auth

import (
	"context"
	"database/sql"
	"errors"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// CreateInvite mints a code an admin can hand to someone however they already
// talk to them. No SMTP involved.
func (s *Service) CreateInvite(ctx context.Context, adminID, label string, expiresAt int64, ip string) (models.Invite, error) {
	admin, err := s.UserByID(ctx, adminID)
	if err != nil {
		return models.Invite{}, err
	}
	if !admin.IsAdmin() {
		return models.Invite{}, ErrForbidden
	}
	label = strings.TrimSpace(label)
	if len(label) > 64 {
		return models.Invite{}, errors.New("auth: a label may be at most 64 characters")
	}
	inv := models.Invite{
		ID: db.NewID(), Code: db.RandomCode(2), Label: label,
		CreatedBy: adminID, ExpiresAt: expiresAt, CreatedAt: db.NowMillis(),
	}
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO invites (id, code, label, created_by, expires_at, created_at)
			VALUES (?, ?, ?, ?, ?, ?)`,
			inv.ID, inv.Code, inv.Label, inv.CreatedBy, db.NullInt64(inv.ExpiresAt), inv.CreatedAt); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: adminID, Action: audit.ActionInviteCreated, IP: ip,
			Metadata: map[string]any{"invite_id": inv.ID, "label": label},
		})
	})
	if err != nil {
		return models.Invite{}, err
	}
	return inv, nil
}

// ListInvites returns active and past invites for the admin screen.
func (s *Service) ListInvites(ctx context.Context, adminID string) ([]models.Invite, error) {
	admin, err := s.UserByID(ctx, adminID)
	if err != nil {
		return nil, err
	}
	if !admin.IsAdmin() {
		return nil, ErrForbidden
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT id, code, label, created_by, expires_at, used_by, used_at, revoked_at, created_at
		FROM invites ORDER BY created_at DESC LIMIT 200`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Invite
	for rows.Next() {
		var (
			inv                          models.Invite
			usedBy                       sql.NullString
			expiresAt, usedAt, revokedAt sql.NullInt64
		)
		if err := rows.Scan(&inv.ID, &inv.Code, &inv.Label, &inv.CreatedBy, &expiresAt,
			&usedBy, &usedAt, &revokedAt, &inv.CreatedAt); err != nil {
			return nil, err
		}
		inv.ExpiresAt = db.Int64OrZero(expiresAt)
		inv.UsedBy = db.StringOrEmpty(usedBy)
		inv.UsedAt = db.Int64OrZero(usedAt)
		inv.RevokedAt = db.Int64OrZero(revokedAt)
		out = append(out, inv)
	}
	return out, rows.Err()
}

// RevokeInvite cancels an unused code.
func (s *Service) RevokeInvite(ctx context.Context, adminID, inviteID, ip string) error {
	admin, err := s.UserByID(ctx, adminID)
	if err != nil {
		return err
	}
	if !admin.IsAdmin() {
		return ErrForbidden
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx,
			`UPDATE invites SET revoked_at = ? WHERE id = ? AND used_at IS NULL AND revoked_at IS NULL`,
			db.NowMillis(), inviteID)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: adminID, Action: audit.ActionInviteRevoked, IP: ip,
			Metadata: map[string]any{"invite_id": inviteID},
		})
	})
}

// CheckInvite reports whether a code can still be redeemed, so onboarding can
// tell someone before they fill in a whole form.
func (s *Service) CheckInvite(ctx context.Context, code string) (models.Invite, error) {
	code = strings.ToUpper(strings.TrimSpace(code))
	var (
		inv                          models.Invite
		usedBy                       sql.NullString
		expiresAt, usedAt, revokedAt sql.NullInt64
	)
	err := s.database.Read().QueryRowContext(ctx, `
		SELECT id, code, label, created_by, expires_at, used_by, used_at, revoked_at, created_at
		FROM invites WHERE code = ?`, code).
		Scan(&inv.ID, &inv.Code, &inv.Label, &inv.CreatedBy, &expiresAt,
			&usedBy, &usedAt, &revokedAt, &inv.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return models.Invite{}, ErrInviteInvalid
	}
	if err != nil {
		return models.Invite{}, err
	}
	inv.ExpiresAt = db.Int64OrZero(expiresAt)
	inv.UsedBy = db.StringOrEmpty(usedBy)
	inv.UsedAt = db.Int64OrZero(usedAt)
	inv.RevokedAt = db.Int64OrZero(revokedAt)
	if !inv.Usable(db.NowMillis()) {
		return models.Invite{}, ErrInviteInvalid
	}
	return inv, nil
}
