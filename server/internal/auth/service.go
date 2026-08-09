package auth

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/settings"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

// Errors this package returns.
var (
	ErrCredentials     = errors.New("auth: username or password is incorrect")
	ErrUserExists      = errors.New("auth: that username is already taken")
	ErrEmailExists     = errors.New("auth: that email is already in use")
	ErrSetupDone       = errors.New("auth: this server is already set up")
	ErrSetupRequired   = errors.New("auth: this server has not been set up yet")
	ErrInviteRequired  = errors.New("auth: an invite code is required to create an account here")
	ErrInviteInvalid   = errors.New("auth: that invite code is not valid")
	ErrSessionInvalid  = errors.New("auth: session is not valid")
	ErrNotFound        = errors.New("auth: not found")
	ErrForbidden       = errors.New("auth: not allowed")
	ErrTOTPRequired    = errors.New("auth: a two-factor code is required")
	ErrTOTPInvalid     = errors.New("auth: that two-factor code is not valid")
	ErrDisabled        = errors.New("auth: this account is disabled")
	ErrInvalidUsername = errors.New("auth: a username must be 3 to 32 characters, letters, digits, dot, dash or underscore")
)

// Service owns accounts, sessions, invites, and the device-approval gate.
type Service struct {
	database *db.DB
	hasher   *Hasher
	tokens   *TokenIssuer
	settings *settings.Service
	audit    *audit.Logger
	hub      *ws.Hub
	log      *slog.Logger

	refreshTTL   time.Duration
	defaultQuota int64
}

// Deps is what a Service needs.
type Deps struct {
	DB           *db.DB
	Hasher       *Hasher
	Tokens       *TokenIssuer
	Settings     *settings.Service
	Audit        *audit.Logger
	Hub          *ws.Hub
	Log          *slog.Logger
	RefreshTTL   time.Duration
	DefaultQuota int64
}

// New returns an auth Service.
func New(d Deps) *Service {
	log := d.Log
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		database: d.DB, hasher: d.Hasher, tokens: d.Tokens, settings: d.Settings,
		audit: d.Audit, hub: d.Hub, log: log,
		refreshTTL: d.RefreshTTL, defaultQuota: d.DefaultQuota,
	}
}

// Tokens exposes the issuer so middleware can verify access tokens.
func (s *Service) Tokens() *TokenIssuer { return s.tokens }

// TokenPair is what a successful login hands back.
type TokenPair struct {
	AccessToken  string
	RefreshToken string
	ExpiresAt    time.Time
	SessionID    string
	User         models.User
}

// DeviceInfo describes the client asking to sign in.
type DeviceInfo struct {
	Name      string
	Platform  string
	IP        string
	UserAgent string
}

// SetupRequired reports whether the server still has zero accounts.
func (s *Service) SetupRequired(ctx context.Context) (bool, error) {
	var count int
	err := s.database.Read().QueryRowContext(ctx, `SELECT COUNT(*) FROM users`).Scan(&count)
	if err != nil {
		return false, err
	}
	return count == 0, nil
}

// SetupParams creates the very first account.
type SetupParams struct {
	Username   string
	Email      string
	Password   string
	ServerName string
	Device     DeviceInfo
}

// Setup creates the first admin. It refuses outright once any user exists, so
// it is a one-time bootstrap and not a standing backdoor.
func (s *Service) Setup(ctx context.Context, p SetupParams) (TokenPair, error) {
	if err := validateUsername(p.Username); err != nil {
		return TokenPair{}, err
	}
	if err := ValidatePassword(p.Password); err != nil {
		return TokenPair{}, err
	}
	hash, err := s.hasher.Hash(p.Password)
	if err != nil {
		return TokenPair{}, err
	}

	var user models.User
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		var count int
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM users`).Scan(&count); err != nil {
			return err
		}
		if count > 0 {
			return ErrSetupDone
		}
		user, err = insertUser(ctx, tx, newUserParams{
			Username: p.Username, Email: p.Email, PasswordHash: hash,
			Role: models.RoleAdmin, Quota: s.defaultQuota,
		})
		if err != nil {
			return err
		}
		if name := strings.TrimSpace(p.ServerName); name != "" {
			if _, err := tx.ExecContext(ctx,
				`UPDATE server_settings SET server_name = ?, updated_at = ? WHERE id = 1`,
				name, db.NowMillis()); err != nil {
				return err
			}
		}
		if err := s.settings.MarkSetupComplete(ctx, tx); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: user.ID, Action: audit.ActionSetupCompleted, IP: p.Device.IP,
			Metadata: map[string]any{"username": user.Username},
		})
	})
	if err != nil {
		return TokenPair{}, err
	}
	if err := s.settings.Refresh(ctx); err != nil {
		s.log.Warn("settings refresh after setup failed", "error", err)
	}
	// the first device on a brand new server is never held for approval
	return s.issueSession(ctx, user, p.Device, false)
}

// RegisterParams creates an ordinary account.
type RegisterParams struct {
	Username   string
	Email      string
	Password   string
	InviteCode string
	Device     DeviceInfo
}

// Register creates an account, consuming an invite unless the server has
// self-registration turned on.
func (s *Service) Register(ctx context.Context, p RegisterParams) (TokenPair, error) {
	if err := validateUsername(p.Username); err != nil {
		return TokenPair{}, err
	}
	if err := ValidatePassword(p.Password); err != nil {
		return TokenPair{}, err
	}
	cfg := s.settings.Get()
	code := strings.ToUpper(strings.TrimSpace(p.InviteCode))
	if !cfg.AllowSelfRegistration && code == "" {
		return TokenPair{}, ErrInviteRequired
	}
	hash, err := s.hasher.Hash(p.Password)
	if err != nil {
		return TokenPair{}, err
	}

	var user models.User
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		var setupCount int
		if err := tx.QueryRowContext(ctx, `SELECT COUNT(*) FROM users`).Scan(&setupCount); err != nil {
			return err
		}
		if setupCount == 0 {
			return ErrSetupRequired
		}

		var inviteID string
		if code != "" {
			var (
				expires   sql.NullInt64
				usedAt    sql.NullInt64
				revokedAt sql.NullInt64
			)
			err := tx.QueryRowContext(ctx,
				`SELECT id, expires_at, used_at, revoked_at FROM invites WHERE code = ?`, code).
				Scan(&inviteID, &expires, &usedAt, &revokedAt)
			if errors.Is(err, sql.ErrNoRows) {
				return ErrInviteInvalid
			}
			if err != nil {
				return err
			}
			inv := models.Invite{
				ExpiresAt: db.Int64OrZero(expires),
				UsedAt:    db.Int64OrZero(usedAt),
				RevokedAt: db.Int64OrZero(revokedAt),
			}
			if !inv.Usable(db.NowMillis()) {
				return ErrInviteInvalid
			}
		}

		user, err = insertUser(ctx, tx, newUserParams{
			Username: p.Username, Email: p.Email, PasswordHash: hash,
			Role: models.RoleMember, Quota: s.defaultQuota,
		})
		if err != nil {
			return err
		}
		if inviteID != "" {
			if _, err := tx.ExecContext(ctx,
				`UPDATE invites SET used_by = ?, used_at = ? WHERE id = ? AND used_at IS NULL`,
				user.ID, db.NowMillis(), inviteID); err != nil {
				return err
			}
			if err := s.audit.RecordTx(ctx, tx, audit.Entry{
				UserID: user.ID, Action: audit.ActionInviteRedeemed, IP: p.Device.IP,
				Metadata: map[string]any{"invite_id": inviteID},
			}); err != nil {
				return err
			}
		}
		// a second account on the server turns device approval on, per the plan
		if _, err := tx.ExecContext(ctx, `
			UPDATE server_settings SET require_device_approval = 1, updated_at = ?
			WHERE id = 1 AND (SELECT COUNT(*) FROM users) > 1`, db.NowMillis()); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: user.ID, Action: audit.ActionUserCreated, IP: p.Device.IP,
			Metadata: map[string]any{"username": user.Username, "self_registered": code == ""},
		})
	})
	if err != nil {
		return TokenPair{}, err
	}
	if err := s.settings.Refresh(ctx); err != nil {
		s.log.Warn("settings refresh after register failed", "error", err)
	}
	// a brand new account's first device has nothing to be approved against
	return s.issueSession(ctx, user, p.Device, false)
}

// LoginParams is one sign-in attempt.
type LoginParams struct {
	Username string
	Password string
	TOTPCode string
	Device   DeviceInfo
}

// LoginResult is either a full token pair or a pending device.
type LoginResult struct {
	Pending      bool
	SessionID    string
	PendingToken string
	Tokens       TokenPair
}

// Login verifies a password, then applies the device-approval gate.
func (s *Service) Login(ctx context.Context, p LoginParams) (LoginResult, error) {
	user, err := s.userByUsername(ctx, p.Username)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			// spend the same work as a real verify so timing does not leak
			// whether the account exists
			_, _, _ = s.hasher.Verify(dummyHash, p.Password)
			s.audit.Record(ctx, audit.Entry{
				Action: audit.ActionLoginFailed, IP: p.Device.IP,
				Metadata: map[string]any{"username": p.Username, "reason": "no such account"},
			})
			return LoginResult{}, ErrCredentials
		}
		return LoginResult{}, err
	}
	if user.DisabledAt != 0 {
		return LoginResult{}, ErrDisabled
	}

	ok, needsRehash, err := s.hasher.Verify(user.PasswordHash, p.Password)
	if err != nil || !ok {
		s.audit.Record(ctx, audit.Entry{
			UserID: user.ID, Action: audit.ActionLoginFailed, IP: p.Device.IP,
			Metadata: map[string]any{"username": p.Username, "reason": "wrong password"},
		})
		return LoginResult{}, ErrCredentials
	}
	if needsRehash {
		if updated, hashErr := s.hasher.Hash(p.Password); hashErr == nil {
			_ = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
				_, err := tx.ExecContext(ctx, `UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?`,
					updated, db.NowMillis(), user.ID)
				return err
			})
		}
	}

	if user.TOTPEnabled {
		if strings.TrimSpace(p.TOTPCode) == "" {
			return LoginResult{}, ErrTOTPRequired
		}
		valid, err := s.verifyTOTP(ctx, user, p.TOTPCode)
		if err != nil {
			return LoginResult{}, err
		}
		if !valid {
			s.audit.Record(ctx, audit.Entry{
				UserID: user.ID, Action: audit.ActionLoginFailed, IP: p.Device.IP,
				Metadata: map[string]any{"reason": "bad two-factor code"},
			})
			return LoginResult{}, ErrTOTPInvalid
		}
	}

	cfg := s.settings.Get()
	needsApproval := false
	if cfg.RequireDeviceApproval {
		var approved int
		err := s.database.Read().QueryRowContext(ctx,
			`SELECT COUNT(*) FROM sessions WHERE user_id = ? AND status = 'active'`, user.ID).Scan(&approved)
		if err != nil {
			return LoginResult{}, err
		}
		needsApproval = approved > 0
	}

	pair, err := s.issueSession(ctx, user, p.Device, needsApproval)
	if err != nil {
		return LoginResult{}, err
	}
	if needsApproval {
		return LoginResult{Pending: true, SessionID: pair.SessionID, PendingToken: pair.AccessToken}, nil
	}
	return LoginResult{Tokens: pair}, nil
}

// issueSession writes a session row and mints its tokens. A pending device
// gets a narrow token that can only poll its own approval status.
func (s *Service) issueSession(ctx context.Context, user models.User, dev DeviceInfo, pending bool) (TokenPair, error) {
	sessionID := db.NewID()
	refresh := ""
	refreshHash := ""
	status := models.SessionActive
	scope := ScopeFull
	if pending {
		status = models.SessionPending
		scope = ScopePending
	} else {
		refresh = db.RandomToken(32)
		refreshHash = db.HashToken(refresh)
	}

	now := db.NowMillis()
	expires := now + s.refreshTTL.Milliseconds()
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `
			INSERT INTO sessions (id, user_id, device_name, platform, status, refresh_token_hash,
			                      ip, user_agent, created_at, last_seen_at, expires_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			sessionID, user.ID, truncate(dev.Name, 64), truncate(dev.Platform, 32), string(status),
			db.NullString(refreshHash), dev.IP, truncate(dev.UserAgent, 256), now, now, expires)
		if err != nil {
			return err
		}
		action := audit.ActionLogin
		if pending {
			action = audit.ActionDevicePending
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: user.ID, Action: action, IP: dev.IP,
			Metadata: map[string]any{"session": sessionID, "device": dev.Name, "platform": dev.Platform},
		})
	})
	if err != nil {
		return TokenPair{}, err
	}

	access, exp, err := s.tokens.Issue(user.ID, sessionID, string(user.Role), scope)
	if err != nil {
		return TokenPair{}, err
	}

	if pending {
		// every already-approved device on this account gets a live prompt
		s.hub.Publish(ws.NewEvent(ws.EventDevicePending, now, map[string]any{
			"session_id": sessionID, "device_name": dev.Name,
			"platform": dev.Platform, "ip": dev.IP, "created_at": now,
		}), user.ID)
	}

	return TokenPair{
		AccessToken: access, RefreshToken: refresh, ExpiresAt: exp,
		SessionID: sessionID, User: user,
	}, nil
}

// SessionStatus reports where a pending device stands. The caller must own
// the session.
func (s *Service) SessionStatus(ctx context.Context, userID, sessionID string) (models.SessionStatus, *TokenPair, error) {
	sess, err := s.sessionByID(ctx, sessionID)
	if err != nil {
		return "", nil, err
	}
	if sess.UserID != userID {
		return "", nil, ErrForbidden
	}
	if sess.Status != models.SessionActive {
		return sess.Status, nil, nil
	}
	// approved since the last poll: hand over the real tokens once
	refresh := db.RandomToken(32)
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx,
			`UPDATE sessions SET refresh_token_hash = ?, last_seen_at = ? WHERE id = ? AND status = 'active'`,
			db.HashToken(refresh), db.NowMillis(), sessionID)
		if err != nil {
			return err
		}
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrSessionInvalid
		}
		return nil
	})
	if err != nil {
		return "", nil, err
	}
	user, err := s.UserByID(ctx, sess.UserID)
	if err != nil {
		return "", nil, err
	}
	access, exp, err := s.tokens.Issue(user.ID, sessionID, string(user.Role), ScopeFull)
	if err != nil {
		return "", nil, err
	}
	return models.SessionActive, &TokenPair{
		AccessToken: access, RefreshToken: refresh, ExpiresAt: exp,
		SessionID: sessionID, User: user,
	}, nil
}

// Refresh rotates a refresh token and mints a new access token.
func (s *Service) Refresh(ctx context.Context, refreshToken, ip string) (TokenPair, error) {
	hash := db.HashToken(refreshToken)
	var (
		sessionID, userID string
		status            string
		expiresAt         sql.NullInt64
	)
	err := s.database.Read().QueryRowContext(ctx,
		`SELECT id, user_id, status, expires_at FROM sessions WHERE refresh_token_hash = ?`, hash).
		Scan(&sessionID, &userID, &status, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return TokenPair{}, ErrSessionInvalid
	}
	if err != nil {
		return TokenPair{}, err
	}
	if models.SessionStatus(status) != models.SessionActive {
		return TokenPair{}, ErrSessionInvalid
	}
	if exp := db.Int64OrZero(expiresAt); exp != 0 && exp <= db.NowMillis() {
		return TokenPair{}, ErrSessionInvalid
	}

	user, err := s.UserByID(ctx, userID)
	if err != nil {
		return TokenPair{}, err
	}
	if user.DisabledAt != 0 {
		return TokenPair{}, ErrDisabled
	}

	next := db.RandomToken(32)
	now := db.NowMillis()
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		res, err := tx.ExecContext(ctx, `
			UPDATE sessions SET refresh_token_hash = ?, last_seen_at = ?, expires_at = ?
			WHERE id = ? AND refresh_token_hash = ?`,
			db.HashToken(next), now, now+s.refreshTTL.Milliseconds(), sessionID, hash)
		if err != nil {
			return err
		}
		// a refresh token is single use; a replayed one finds nothing to rotate
		if n, _ := res.RowsAffected(); n == 0 {
			return ErrSessionInvalid
		}
		return nil
	})
	if err != nil {
		return TokenPair{}, err
	}

	access, exp, err := s.tokens.Issue(user.ID, sessionID, string(user.Role), ScopeFull)
	if err != nil {
		return TokenPair{}, err
	}
	return TokenPair{
		AccessToken: access, RefreshToken: next, ExpiresAt: exp,
		SessionID: sessionID, User: user,
	}, nil
}

// Logout revokes the calling session.
func (s *Service) Logout(ctx context.Context, userID, sessionID, ip string) error {
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`UPDATE sessions SET status = 'revoked', revoked_at = ?, refresh_token_hash = NULL
			 WHERE id = ? AND user_id = ?`, db.NowMillis(), sessionID, userID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, Action: audit.ActionLogout, IP: ip,
			Metadata: map[string]any{"session": sessionID},
		})
	})
	return err
}

// ValidateSession confirms a token's session is still usable and returns the
// account behind it.
func (s *Service) ValidateSession(ctx context.Context, userID, sessionID string) (models.User, models.Session, error) {
	sess, err := s.sessionByID(ctx, sessionID)
	if err != nil {
		return models.User{}, models.Session{}, err
	}
	if sess.UserID != userID {
		return models.User{}, models.Session{}, ErrSessionInvalid
	}
	if sess.Status == models.SessionRevoked || sess.Status == models.SessionDenied {
		return models.User{}, models.Session{}, ErrSessionInvalid
	}
	user, err := s.UserByID(ctx, userID)
	if err != nil {
		return models.User{}, models.Session{}, err
	}
	if user.DisabledAt != 0 {
		return models.User{}, models.Session{}, ErrDisabled
	}
	return user, sess, nil
}

const dummyHash = "$argon2id$v=19$m=65536,t=2,p=2$YWJjZGVmZ2hpamtsbW5vcA$1YQq0j2hxWvT2yV0nJqLxHf5g8sZ0qP7mQ2cH1nA8xk"

func truncate(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[:max]
}

func validateUsername(name string) error {
	name = strings.TrimSpace(name)
	if len(name) < 3 || len(name) > 32 {
		return ErrInvalidUsername
	}
	for _, r := range name {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '.' || r == '-' || r == '_':
		default:
			return ErrInvalidUsername
		}
	}
	return nil
}

func normalizeEmail(email string) (string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return "", nil
	}
	at := strings.IndexByte(email, '@')
	if at <= 0 || at == len(email)-1 || strings.Count(email, "@") != 1 {
		return "", fmt.Errorf("auth: %q is not a usable email address", email)
	}
	return email, nil
}
