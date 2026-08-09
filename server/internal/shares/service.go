// Package shares covers both ways content leaves one account: a public
// tokenized link for anyone without an account, and a direct grant to another
// account on this same server.
package shares

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/auth"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/files"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

// Errors this package returns.
var (
	ErrNotFound        = errors.New("shares: share not found")
	ErrExpired         = errors.New("shares: this link has expired")
	ErrPasswordNeeded  = errors.New("shares: this link needs a password")
	ErrPasswordWrong   = errors.New("shares: that password is not correct")
	ErrDownloadBlocked = errors.New("shares: this link is view only")
	ErrForbidden       = errors.New("shares: not allowed")
	ErrInvalid         = errors.New("shares: invalid request")
	ErrSelfShare       = errors.New("shares: you already own this")
)

// Service owns shares and permissions.
type Service struct {
	database *db.DB
	files    *files.Service
	hasher   *auth.Hasher
	audit    *audit.Logger
	hub      *ws.Hub
	log      *slog.Logger
	baseURL  string
}

// Deps is what a Service needs.
type Deps struct {
	DB      *db.DB
	Files   *files.Service
	Hasher  *auth.Hasher
	Audit   *audit.Logger
	Hub     *ws.Hub
	Log     *slog.Logger
	BaseURL string
}

// New returns a shares Service.
func New(d Deps) *Service {
	log := d.Log
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		database: d.DB, files: d.Files, hasher: d.Hasher, audit: d.Audit,
		hub: d.Hub, log: log, baseURL: strings.TrimSuffix(d.BaseURL, "/"),
	}
}

// CreateParams describes a new public link.
type CreateParams struct {
	UserID        string
	NodeID        string
	Password      string
	ExpiresAt     int64
	AllowDownload bool
	IP            string
}

// Create makes a share link. Owner only, per the capability matrix.
func (s *Service) Create(ctx context.Context, p CreateParams) (models.Share, error) {
	acc, err := s.files.Resolve(ctx, p.UserID, p.NodeID)
	if err != nil {
		return models.Share{}, err
	}
	if err := acc.Require(files.CapShare); err != nil {
		return models.Share{}, err
	}
	if p.ExpiresAt != 0 && p.ExpiresAt <= db.NowMillis() {
		return models.Share{}, fmt.Errorf("%w: an expiry in the past", ErrInvalid)
	}
	passwordHash := ""
	if p.Password != "" {
		if err := auth.ValidatePassword(p.Password); err != nil {
			return models.Share{}, err
		}
		passwordHash, err = s.hasher.Hash(p.Password)
		if err != nil {
			return models.Share{}, err
		}
	}

	share := models.Share{
		ID: db.NewID(), NodeID: p.NodeID, Token: db.RandomToken(16),
		PasswordHash: passwordHash, ExpiresAt: p.ExpiresAt,
		AllowDownload: p.AllowDownload, CreatedBy: p.UserID, CreatedAt: db.NowMillis(),
	}
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO shares (id, node_id, token, password_hash, expires_at, allow_download,
			                    created_by, created_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
			share.ID, share.NodeID, share.Token, db.NullString(share.PasswordHash),
			db.NullInt64(share.ExpiresAt), boolInt(share.AllowDownload), share.CreatedBy, share.CreatedAt); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: p.UserID, NodeID: p.NodeID, Action: audit.ActionShareCreated, IP: p.IP,
			Metadata: map[string]any{
				"share_id": share.ID, "expires_at": share.ExpiresAt,
				"password_protected": passwordHash != "", "allow_download": share.AllowDownload,
			},
		})
	})
	if err != nil {
		return models.Share{}, err
	}
	return share, nil
}

// UpdateParams changes an existing link without changing its URL.
type UpdateParams struct {
	UserID        string
	ShareID       string
	ExpiresAt     *int64
	Password      *string // empty string removes the password
	AllowDownload *bool
	IP            string
}

// Update edits a share in place.
func (s *Service) Update(ctx context.Context, p UpdateParams) (models.Share, error) {
	share, err := s.byID(ctx, p.ShareID)
	if err != nil {
		return models.Share{}, err
	}
	acc, err := s.files.Resolve(ctx, p.UserID, share.NodeID)
	if err != nil {
		return models.Share{}, err
	}
	if err := acc.Require(files.CapShare); err != nil {
		return models.Share{}, err
	}

	sets := []string{}
	args := []any{}
	if p.ExpiresAt != nil {
		if *p.ExpiresAt != 0 && *p.ExpiresAt <= db.NowMillis() {
			return models.Share{}, fmt.Errorf("%w: an expiry in the past", ErrInvalid)
		}
		sets = append(sets, "expires_at = ?")
		args = append(args, db.NullInt64(*p.ExpiresAt))
		share.ExpiresAt = *p.ExpiresAt
	}
	if p.Password != nil {
		if *p.Password == "" {
			sets = append(sets, "password_hash = NULL")
			share.PasswordHash = ""
		} else {
			if err := auth.ValidatePassword(*p.Password); err != nil {
				return models.Share{}, err
			}
			hash, err := s.hasher.Hash(*p.Password)
			if err != nil {
				return models.Share{}, err
			}
			sets = append(sets, "password_hash = ?")
			args = append(args, hash)
			share.PasswordHash = hash
		}
	}
	if p.AllowDownload != nil {
		sets = append(sets, "allow_download = ?")
		args = append(args, boolInt(*p.AllowDownload))
		share.AllowDownload = *p.AllowDownload
	}
	if len(sets) == 0 {
		return share, nil
	}
	args = append(args, p.ShareID)

	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`UPDATE shares SET `+strings.Join(sets, ", ")+` WHERE id = ?`, args...); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: p.UserID, NodeID: share.NodeID, Action: audit.ActionShareUpdated, IP: p.IP,
			Metadata: map[string]any{"share_id": p.ShareID},
		})
	})
	if err != nil {
		return models.Share{}, err
	}
	return share, nil
}

// Revoke kills a link immediately.
func (s *Service) Revoke(ctx context.Context, userID, shareID, ip string) error {
	share, err := s.byID(ctx, shareID)
	if err != nil {
		return err
	}
	acc, err := s.files.Resolve(ctx, userID, share.NodeID)
	if err != nil {
		return err
	}
	if err := acc.Require(files.CapShare); err != nil {
		return err
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`UPDATE shares SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL`,
			db.NowMillis(), shareID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, NodeID: share.NodeID, Action: audit.ActionShareRevoked, IP: ip,
			Metadata: map[string]any{"share_id": shareID},
		})
	})
}

// ListForNode returns the links on one node.
func (s *Service) ListForNode(ctx context.Context, userID, nodeID string) ([]models.Share, error) {
	acc, err := s.files.Resolve(ctx, userID, nodeID)
	if err != nil {
		return nil, err
	}
	if err := acc.Require(files.CapShare); err != nil {
		return nil, err
	}
	return s.query(ctx, `WHERE node_id = ? ORDER BY created_at DESC`, nodeID)
}

// ListByUser powers the Shared by me screen.
func (s *Service) ListByUser(ctx context.Context, userID string) ([]models.Share, error) {
	return s.query(ctx, `WHERE created_by = ? AND revoked_at IS NULL ORDER BY created_at DESC LIMIT 200`, userID)
}

// Resolved is a public share plus the node behind it.
type Resolved struct {
	Share models.Share
	Node  models.Node
}

// ResolvePublic is the live check on every single access to a link. Expiry is
// enforced here, in the same request that would serve the file, not by the
// background sweep.
func (s *Service) ResolvePublic(ctx context.Context, token, password string) (Resolved, error) {
	shares, err := s.query(ctx, `WHERE token = ?`, token)
	if err != nil {
		return Resolved{}, err
	}
	if len(shares) == 0 {
		return Resolved{}, ErrNotFound
	}
	share := shares[0]
	if share.RevokedAt != 0 {
		return Resolved{}, ErrNotFound
	}
	if share.ExpiresAt != 0 && share.ExpiresAt <= db.NowMillis() {
		return Resolved{}, ErrExpired
	}
	if share.PasswordHash != "" {
		if password == "" {
			return Resolved{Share: models.Share{ID: share.ID}}, ErrPasswordNeeded
		}
		ok, _, err := s.hasher.Verify(share.PasswordHash, password)
		if err != nil || !ok {
			return Resolved{}, ErrPasswordWrong
		}
	}
	node, err := s.files.GetNode(ctx, share.NodeID)
	if err != nil {
		return Resolved{}, ErrNotFound
	}
	if node.TrashedAt != 0 || node.DeletedAt != 0 {
		return Resolved{}, ErrNotFound
	}
	return Resolved{Share: share, Node: node}, nil
}

// PublicChild resolves one node inside a shared folder, so a link to a folder
// can be browsed without granting access to anything outside it.
func (s *Service) PublicChild(ctx context.Context, share models.Share, nodeID string) (models.Node, error) {
	node, err := s.files.GetNode(ctx, nodeID)
	if err != nil {
		return models.Node{}, ErrNotFound
	}
	if node.TrashedAt != 0 {
		return models.Node{}, ErrNotFound
	}
	if node.ID == share.NodeID {
		return node, nil
	}
	var inside int
	err = s.database.Read().QueryRowContext(ctx, `
		WITH RECURSIVE chain(id, parent_id, depth) AS (
			SELECT id, parent_id, 0 FROM nodes WHERE id = ? AND deleted_at IS NULL
			UNION ALL
			SELECT n.id, n.parent_id, c.depth + 1 FROM nodes n JOIN chain c ON n.id = c.parent_id
			WHERE c.depth < 128 AND n.deleted_at IS NULL AND n.trashed_at IS NULL
		)
		SELECT COUNT(*) FROM chain WHERE id = ?`, nodeID, share.NodeID).Scan(&inside)
	if err != nil {
		return models.Node{}, err
	}
	if inside == 0 {
		return models.Node{}, ErrNotFound
	}
	return node, nil
}

// RecordAccess writes an audit row for one public hit on a link.
func (s *Service) RecordAccess(ctx context.Context, share models.Share, ip, action string) {
	s.audit.Record(ctx, audit.Entry{
		UserID: share.CreatedBy, NodeID: share.NodeID, Action: audit.ActionShareAccessed, IP: ip,
		Metadata: map[string]any{"share_id": share.ID, "kind": action},
	})
}

// SweepExpired marks past-expiry links revoked and logs it. Hygiene and audit
// trail only; the real check is the live one in ResolvePublic.
func (s *Service) SweepExpired(ctx context.Context) error {
	now := db.NowMillis()
	rows, err := s.database.Read().QueryContext(ctx,
		`SELECT id, node_id, created_by FROM shares
		 WHERE revoked_at IS NULL AND expires_at IS NOT NULL AND expires_at <= ?`, now)
	if err != nil {
		return err
	}
	type expired struct{ id, nodeID, creator string }
	var list []expired
	for rows.Next() {
		var e expired
		if err := rows.Scan(&e.id, &e.nodeID, &e.creator); err != nil {
			rows.Close()
			return err
		}
		list = append(list, e)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	if len(list) == 0 {
		return nil
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		for _, e := range list {
			if _, err := tx.ExecContext(ctx, `UPDATE shares SET revoked_at = ? WHERE id = ?`, now, e.id); err != nil {
				return err
			}
			if err := s.audit.RecordTx(ctx, tx, audit.Entry{
				UserID: e.creator, NodeID: e.nodeID, Action: audit.ActionShareExpired,
				Metadata: map[string]any{"share_id": e.id},
			}); err != nil {
				return err
			}
		}
		return nil
	})
}

// URL builds the absolute link for a share, since a bare path is ambiguous
// across self-hosted servers.
func (s *Service) URL(share models.Share) string {
	if s.baseURL == "" {
		return "/s/" + share.Token
	}
	return s.baseURL + "/s/" + share.Token
}

func (s *Service) byID(ctx context.Context, id string) (models.Share, error) {
	list, err := s.query(ctx, `WHERE id = ?`, id)
	if err != nil {
		return models.Share{}, err
	}
	if len(list) == 0 {
		return models.Share{}, ErrNotFound
	}
	return list[0], nil
}

func (s *Service) query(ctx context.Context, where string, args ...any) ([]models.Share, error) {
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT id, node_id, token, password_hash, expires_at, allow_download, created_by,
		       created_at, revoked_at
		FROM shares `+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Share
	for rows.Next() {
		var (
			sh                   models.Share
			passwordHash         sql.NullString
			expiresAt, revokedAt sql.NullInt64
			allowDownload        int
		)
		if err := rows.Scan(&sh.ID, &sh.NodeID, &sh.Token, &passwordHash, &expiresAt,
			&allowDownload, &sh.CreatedBy, &sh.CreatedAt, &revokedAt); err != nil {
			return nil, err
		}
		sh.PasswordHash = db.StringOrEmpty(passwordHash)
		sh.ExpiresAt = db.Int64OrZero(expiresAt)
		sh.RevokedAt = db.Int64OrZero(revokedAt)
		sh.AllowDownload = allowDownload != 0
		out = append(out, sh)
	}
	return out, rows.Err()
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
