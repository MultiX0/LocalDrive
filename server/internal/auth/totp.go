package auth

import (
	"context"
	"crypto/subtle"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"

	"github.com/pquerna/otp/totp"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// recoveryCodeCount is how many single-use codes are minted at enrollment.
const recoveryCodeCount = 8

// TOTPEnrollment is what the client needs to finish setting up two-factor.
type TOTPEnrollment struct {
	Secret        string
	OTPAuthURL    string
	RecoveryCodes []string
}

// BeginTOTP generates a secret and its provisioning URL. Nothing is enabled
// until ConfirmTOTP succeeds with a real code from the authenticator.
func (s *Service) BeginTOTP(ctx context.Context, userID string) (TOTPEnrollment, error) {
	user, err := s.UserByID(ctx, userID)
	if err != nil {
		return TOTPEnrollment{}, err
	}
	if user.TOTPEnabled {
		return TOTPEnrollment{}, errors.New("auth: two-factor is already on for this account")
	}
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer:      s.settings.Get().ServerName,
		AccountName: user.Username,
		Secret:      []byte(db.RandomBase32(20)),
	})
	if err != nil {
		return TOTPEnrollment{}, err
	}
	codes := make([]string, 0, recoveryCodeCount)
	hashes := make([]string, 0, recoveryCodeCount)
	for i := 0; i < recoveryCodeCount; i++ {
		code := db.RandomCode(3)
		codes = append(codes, code)
		hashes = append(hashes, db.HashToken(code))
	}
	encoded, err := json.Marshal(hashes)
	if err != nil {
		return TOTPEnrollment{}, err
	}
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx,
			`UPDATE users SET totp_secret = ?, totp_enabled = 0, totp_recovery_json = ?, updated_at = ?
			 WHERE id = ?`, key.Secret(), string(encoded), db.NowMillis(), userID)
		return err
	})
	if err != nil {
		return TOTPEnrollment{}, err
	}
	return TOTPEnrollment{Secret: key.Secret(), OTPAuthURL: key.URL(), RecoveryCodes: codes}, nil
}

// ConfirmTOTP turns two-factor on once the client proves it can generate a
// current code.
func (s *Service) ConfirmTOTP(ctx context.Context, userID, code, ip string) error {
	user, err := s.UserByID(ctx, userID)
	if err != nil {
		return err
	}
	if user.TOTPSecret == "" {
		return errors.New("auth: start two-factor setup first")
	}
	if !totp.Validate(strings.TrimSpace(code), user.TOTPSecret) {
		return ErrTOTPInvalid
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`UPDATE users SET totp_enabled = 1, updated_at = ? WHERE id = ?`, db.NowMillis(), userID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, Action: audit.ActionTOTPEnabled, IP: ip,
		})
	})
}

// DisableTOTP turns two-factor off after confirming the account password.
func (s *Service) DisableTOTP(ctx context.Context, userID, password, ip string) error {
	user, err := s.UserByID(ctx, userID)
	if err != nil {
		return err
	}
	ok, _, err := s.hasher.Verify(user.PasswordHash, password)
	if err != nil || !ok {
		return ErrCredentials
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`UPDATE users SET totp_enabled = 0, totp_secret = NULL, totp_recovery_json = NULL, updated_at = ?
			 WHERE id = ?`, db.NowMillis(), userID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, Action: audit.ActionTOTPDisabled, IP: ip,
		})
	})
}

// verifyTOTP accepts either a current authenticator code or one unused
// recovery code, which is then consumed.
func (s *Service) verifyTOTP(ctx context.Context, user models.User, code string) (bool, error) {
	code = strings.TrimSpace(code)
	if totp.Validate(code, user.TOTPSecret) {
		return true, nil
	}
	var stored sql.NullString
	if err := s.database.Read().QueryRowContext(ctx,
		`SELECT totp_recovery_json FROM users WHERE id = ?`, user.ID).Scan(&stored); err != nil {
		return false, err
	}
	if !stored.Valid || stored.String == "" {
		return false, nil
	}
	var hashes []string
	if err := json.Unmarshal([]byte(stored.String), &hashes); err != nil {
		return false, nil
	}
	candidate := db.HashToken(strings.ToUpper(code))
	remaining := make([]string, 0, len(hashes))
	matched := false
	for _, h := range hashes {
		if !matched && subtle.ConstantTimeCompare([]byte(h), []byte(candidate)) == 1 {
			matched = true
			continue
		}
		remaining = append(remaining, h)
	}
	if !matched {
		return false, nil
	}
	encoded, err := json.Marshal(remaining)
	if err != nil {
		return false, err
	}
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `UPDATE users SET totp_recovery_json = ?, updated_at = ? WHERE id = ?`,
			string(encoded), db.NowMillis(), user.ID)
		return err
	})
	return true, err
}
