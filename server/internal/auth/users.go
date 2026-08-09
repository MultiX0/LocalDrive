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

const userColumns = `id, email, username, display_name, password_hash, must_change_password, role,
	quota_bytes, quota_bytes_used, avatar_seed, totp_secret, totp_enabled, disabled_at,
	created_at, updated_at`

type userScanner interface {
	Scan(dest ...any) error
}

func scanUser(row userScanner) (models.User, error) {
	var (
		u                  models.User
		email, totpSecret  sql.NullString
		mustChange, totpOn int
		disabledAt         sql.NullInt64
		role               string
	)
	err := row.Scan(&u.ID, &email, &u.Username, &u.DisplayName, &u.PasswordHash, &mustChange, &role,
		&u.QuotaBytes, &u.QuotaBytesUsed, &u.AvatarSeed, &totpSecret, &totpOn, &disabledAt,
		&u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return models.User{}, err
	}
	u.Email = db.StringOrEmpty(email)
	u.TOTPSecret = db.StringOrEmpty(totpSecret)
	u.MustChangePassword = mustChange != 0
	u.TOTPEnabled = totpOn != 0
	u.DisabledAt = db.Int64OrZero(disabledAt)
	u.Role = models.Role(role)
	return u, nil
}

type newUserParams struct {
	Username     string
	Email        string
	PasswordHash string
	Role         models.Role
	Quota        int64
	MustChange   bool
}

func insertUser(ctx context.Context, tx *sql.Tx, p newUserParams) (models.User, error) {
	email, err := normalizeEmail(p.Email)
	if err != nil {
		return models.User{}, err
	}
	username := strings.TrimSpace(p.Username)

	var clash int
	if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE lower(username) = lower(?)`, username).Scan(&clash); err != nil {
		return models.User{}, err
	}
	if clash > 0 {
		return models.User{}, ErrUserExists
	}
	if email != "" {
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE email = ?`, email).Scan(&clash); err != nil {
			return models.User{}, err
		}
		if clash > 0 {
			return models.User{}, ErrEmailExists
		}
	}

	now := db.NowMillis()
	u := models.User{
		ID: db.NewID(), Username: username, Email: email, DisplayName: username,
		PasswordHash: p.PasswordHash, Role: p.Role, QuotaBytes: p.Quota,
		AvatarSeed: db.RandomToken(8), MustChangePassword: p.MustChange,
		CreatedAt: now, UpdatedAt: now,
	}
	_, err = tx.ExecContext(ctx, `
		INSERT INTO users (id, email, username, display_name, password_hash, must_change_password,
		                   role, quota_bytes, quota_bytes_used, avatar_seed, totp_enabled,
		                   created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 0, ?, ?)`,
		u.ID, db.NullString(u.Email), u.Username, u.DisplayName, u.PasswordHash,
		boolInt(u.MustChangePassword), string(u.Role), u.QuotaBytes, u.AvatarSeed, now, now)
	if err != nil {
		return models.User{}, err
	}
	return u, nil
}

// UserByID loads one account.
func (s *Service) UserByID(ctx context.Context, id string) (models.User, error) {
	row := s.database.Read().QueryRowContext(ctx, `SELECT `+userColumns+` FROM users WHERE id = ?`, id)
	u, err := scanUser(row)
	if errors.Is(err, sql.ErrNoRows) {
		return models.User{}, ErrNotFound
	}
	return u, err
}

func (s *Service) userByUsername(ctx context.Context, username string) (models.User, error) {
	row := s.database.Read().QueryRowContext(ctx,
		`SELECT `+userColumns+` FROM users WHERE lower(username) = lower(?)`, strings.TrimSpace(username))
	u, err := scanUser(row)
	if errors.Is(err, sql.ErrNoRows) {
		return models.User{}, ErrNotFound
	}
	return u, err
}

// PublicUser is what every account may see about another account: a name and
// an avatar seed, never an email or a role.
type PublicUser struct {
	ID         string
	Name       string
	AvatarSeed string
}

// ListPublicUsers powers the People picker in the share sheet.
func (s *Service) ListPublicUsers(ctx context.Context, query string) ([]PublicUser, error) {
	sqlText := `SELECT id, username, display_name, avatar_seed FROM users WHERE disabled_at IS NULL`
	var args []any
	if q := strings.TrimSpace(query); q != "" {
		sqlText += ` AND (username LIKE ? OR display_name LIKE ?)`
		pattern := "%" + q + "%"
		args = append(args, pattern, pattern)
	}
	sqlText += ` ORDER BY display_name COLLATE NOCASE, username COLLATE NOCASE LIMIT 500`
	rows, err := s.database.Read().QueryContext(ctx, sqlText, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []PublicUser
	for rows.Next() {
		var id, username, display, seed string
		if err := rows.Scan(&id, &username, &display, &seed); err != nil {
			return nil, err
		}
		name := display
		if name == "" {
			name = username
		}
		out = append(out, PublicUser{ID: id, Name: name, AvatarSeed: seed})
	}
	return out, rows.Err()
}

// ListUsers is the admin view, with the fields the People picker hides.
func (s *Service) ListUsers(ctx context.Context) ([]models.User, error) {
	rows, err := s.database.Read().QueryContext(ctx,
		`SELECT `+userColumns+` FROM users ORDER BY created_at`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.User
	for rows.Next() {
		u, err := scanUser(rows)
		if err != nil {
			return nil, err
		}
		u.PasswordHash = ""
		u.TOTPSecret = ""
		out = append(out, u)
	}
	return out, rows.Err()
}

// ChangePassword updates the caller's own password and clears the
// must-change flag.
func (s *Service) ChangePassword(ctx context.Context, userID, current, next, ip string) error {
	if err := ValidatePassword(next); err != nil {
		return err
	}
	user, err := s.UserByID(ctx, userID)
	if err != nil {
		return err
	}
	// an account still on a temporary password proves nothing by repeating it,
	// but every other account must confirm the one it is replacing
	if !user.MustChangePassword {
		ok, _, err := s.hasher.Verify(user.PasswordHash, current)
		if err != nil || !ok {
			return ErrCredentials
		}
	}
	hash, err := s.hasher.Hash(next)
	if err != nil {
		return err
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`UPDATE users SET password_hash = ?, must_change_password = 0, updated_at = ? WHERE id = ?`,
			hash, db.NowMillis(), userID); err != nil {
			return err
		}
		// changing a password ends every other session on the account
		if _, err := tx.ExecContext(ctx,
			`UPDATE sessions SET status = 'revoked', revoked_at = ?, refresh_token_hash = NULL
			 WHERE user_id = ? AND status = 'pending'`, db.NowMillis(), userID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, Action: audit.ActionPasswordChanged, IP: ip,
		})
	})
}

// AdminResetPassword issues a temporary password for a locked-out account.
// This path always works, since it never depends on SMTP being configured.
func (s *Service) AdminResetPassword(ctx context.Context, adminID, targetID, newPassword, ip string) (string, error) {
	admin, err := s.UserByID(ctx, adminID)
	if err != nil {
		return "", err
	}
	if !admin.IsAdmin() {
		return "", ErrForbidden
	}
	if newPassword == "" {
		newPassword = db.RandomCode(3)
	}
	if err := ValidatePassword(newPassword); err != nil {
		return "", err
	}
	hash, err := s.hasher.Hash(newPassword)
	if err != nil {
		return "", err
	}
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx,
			`UPDATE users SET password_hash = ?, must_change_password = 1, updated_at = ? WHERE id = ?`,
			hash, db.NowMillis(), targetID)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		if _, err := tx.ExecContext(ctx,
			`UPDATE sessions SET status = 'revoked', revoked_at = ?, refresh_token_hash = NULL WHERE user_id = ?`,
			db.NowMillis(), targetID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: adminID, Action: audit.ActionPasswordReset, IP: ip,
			Metadata: map[string]any{"target_user": targetID},
		})
	})
	if err != nil {
		return "", err
	}
	return newPassword, nil
}

// SetRole promotes or demotes an account. The last admin cannot be demoted.
func (s *Service) SetRole(ctx context.Context, adminID, targetID string, role models.Role, ip string) error {
	if role != models.RoleAdmin && role != models.RoleMember {
		return ErrForbidden
	}
	admin, err := s.UserByID(ctx, adminID)
	if err != nil {
		return err
	}
	if !admin.IsAdmin() {
		return ErrForbidden
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if role == models.RoleMember {
			var admins int
			if err := tx.QueryRowContext(ctx,
				`SELECT COUNT(*) FROM users WHERE role = 'admin' AND disabled_at IS NULL AND id != ?`,
				targetID).Scan(&admins); err != nil {
				return err
			}
			if admins == 0 {
				return errors.New("auth: this is the only admin account, promote someone else first")
			}
		}
		res, err := tx.ExecContext(ctx, `UPDATE users SET role = ?, updated_at = ? WHERE id = ?`,
			string(role), db.NowMillis(), targetID)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: adminID, Action: audit.ActionUserRoleChanged, IP: ip,
			Metadata: map[string]any{"target_user": targetID, "role": string(role)},
		})
	})
}

// SetQuota changes how much space an account may use. Zero means unlimited.
func (s *Service) SetQuota(ctx context.Context, adminID, targetID string, quota int64, ip string) error {
	admin, err := s.UserByID(ctx, adminID)
	if err != nil {
		return err
	}
	if !admin.IsAdmin() {
		return ErrForbidden
	}
	if quota < 0 {
		return ErrForbidden
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx, `UPDATE users SET quota_bytes = ?, updated_at = ? WHERE id = ?`,
			quota, db.NowMillis(), targetID)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrNotFound
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: adminID, Action: audit.ActionSettingsChanged, IP: ip,
			Metadata: map[string]any{"target_user": targetID, "quota_bytes": quota},
		})
	})
}

// SetDisabled locks or unlocks an account.
func (s *Service) SetDisabled(ctx context.Context, adminID, targetID string, disabled bool, ip string) error {
	admin, err := s.UserByID(ctx, adminID)
	if err != nil {
		return err
	}
	if !admin.IsAdmin() {
		return ErrForbidden
	}
	if adminID == targetID {
		return errors.New("auth: an admin cannot disable their own account")
	}
	var at any
	if disabled {
		at = db.NowMillis()
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `UPDATE users SET disabled_at = ?, updated_at = ? WHERE id = ?`,
			at, db.NowMillis(), targetID); err != nil {
			return err
		}
		if disabled {
			if _, err := tx.ExecContext(ctx,
				`UPDATE sessions SET status = 'revoked', revoked_at = ?, refresh_token_hash = NULL WHERE user_id = ?`,
				db.NowMillis(), targetID); err != nil {
				return err
			}
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: adminID, Action: audit.ActionUserDisabled, IP: ip,
			Metadata: map[string]any{"target_user": targetID, "disabled": disabled},
		})
	})
}

// UpdateProfile changes the caller's own display name.
func (s *Service) UpdateProfile(ctx context.Context, userID, displayName string) error {
	name := strings.TrimSpace(displayName)
	if name == "" || len(name) > 64 {
		return errors.New("auth: a display name must be 1 to 64 characters")
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `UPDATE users SET display_name = ?, updated_at = ? WHERE id = ?`,
			name, db.NowMillis(), userID)
		return err
	})
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
