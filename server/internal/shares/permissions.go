package shares

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/files"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

// Grant is one person's access to one node, as shown in the share sheet.
type Grant struct {
	UserID     string
	Name       string
	AvatarSeed string
	Role       string
	CreatedAt  int64
}

// GrantAccess shares a node with another account on this server. One row on a
// folder covers everything inside it.
func (s *Service) GrantAccess(ctx context.Context, ownerID, nodeID, targetUserID, role, ip string) (Grant, error) {
	if role != "viewer" && role != "editor" {
		return Grant{}, fmt.Errorf("%w: role must be viewer or editor", ErrInvalid)
	}
	acc, err := s.files.Resolve(ctx, ownerID, nodeID)
	if err != nil {
		return Grant{}, err
	}
	if err := acc.Require(files.CapShare); err != nil {
		return Grant{}, err
	}
	if targetUserID == acc.Node.OwnerID {
		return Grant{}, ErrSelfShare
	}

	var grant Grant
	err = s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		var username, display, seed string
		if err := tx.QueryRowContext(ctx,
			`SELECT username, display_name, avatar_seed FROM users WHERE id = ? AND disabled_at IS NULL`,
			targetUserID).Scan(&username, &display, &seed); err != nil {
			if err == sql.ErrNoRows {
				return fmt.Errorf("%w: no such account", ErrInvalid)
			}
			return err
		}
		now := db.NowMillis()
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO permissions (id, node_id, user_id, role, created_by, created_at)
			VALUES (?, ?, ?, ?, ?, ?)
			ON CONFLICT (node_id, user_id) DO UPDATE SET role = excluded.role`,
			db.NewID(), nodeID, targetUserID, role, ownerID, now); err != nil {
			return err
		}
		name := display
		if name == "" {
			name = username
		}
		grant = Grant{UserID: targetUserID, Name: name, AvatarSeed: seed, Role: role, CreatedAt: now}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: ownerID, NodeID: nodeID, Action: audit.ActionPermissionGranted, IP: ip,
			Metadata: map[string]any{"target_user": targetUserID, "role": role},
		})
	})
	if err != nil {
		return Grant{}, err
	}

	// the receiving device gets a warm, specific toast rather than a generic
	// notification, so the event carries who shared what
	s.hub.Publish(ws.NewEvent(ws.EventShareReceived, db.NowMillis(), map[string]any{
		"node_id":   nodeID,
		"node_name": acc.Node.Name,
		"node_type": string(acc.Node.Type),
		"owner_id":  acc.Node.OwnerID,
		"role":      role,
	}), targetUserID)
	return grant, nil
}

// RevokeAccess removes one person's access. Immediate, with no link to rotate.
func (s *Service) RevokeAccess(ctx context.Context, ownerID, nodeID, targetUserID, ip string) error {
	acc, err := s.files.Resolve(ctx, ownerID, nodeID)
	if err != nil {
		return err
	}
	if err := acc.Require(files.CapShare); err != nil {
		return err
	}
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if _, err := tx.ExecContext(ctx,
			`DELETE FROM permissions WHERE node_id = ? AND user_id = ?`, nodeID, targetUserID); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: ownerID, NodeID: nodeID, Action: audit.ActionPermissionRevoked, IP: ip,
			Metadata: map[string]any{"target_user": targetUserID},
		})
	})
}

// ListGrants returns everyone this node is shared with directly.
func (s *Service) ListGrants(ctx context.Context, userID, nodeID string) ([]Grant, error) {
	acc, err := s.files.Resolve(ctx, userID, nodeID)
	if err != nil {
		return nil, err
	}
	if err := acc.Require(files.CapBrowse); err != nil {
		return nil, err
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT p.user_id, u.username, u.display_name, u.avatar_seed, p.role, p.created_at
		FROM permissions p JOIN users u ON u.id = p.user_id
		WHERE p.node_id = ? ORDER BY u.display_name COLLATE NOCASE`, nodeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Grant
	for rows.Next() {
		var g Grant
		var username, display string
		if err := rows.Scan(&g.UserID, &username, &display, &g.AvatarSeed, &g.Role, &g.CreatedAt); err != nil {
			return nil, err
		}
		g.Name = display
		if g.Name == "" {
			g.Name = username
		}
		out = append(out, g)
	}
	return out, rows.Err()
}

// OwnerOf returns a node's owner reference for the shared-item badge.
func (s *Service) OwnerOf(ctx context.Context, node models.Node) (string, error) {
	var username, display string
	err := s.database.Read().QueryRowContext(ctx,
		`SELECT username, display_name FROM users WHERE id = ?`, node.OwnerID).Scan(&username, &display)
	if err != nil {
		return "", err
	}
	if display != "" {
		return display, nil
	}
	return username, nil
}
