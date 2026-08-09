package files

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/jobs"
	"github.com/MultiX0/LocalDrive/server/internal/libraries"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/storage"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
	"github.com/MultiX0/LocalDrive/server/pkg/pathsafe"
)

// CreateFolderParams describes a new folder.
type CreateFolderParams struct {
	UserID    string
	ParentID  string
	Name      string
	LibraryID string // only consulted for a top-level folder
	Color     string
	IP        string
}

// CreateFolder makes a folder. A folder inside another folder inherits its
// parent's library and owner; only a top-level folder chooses a library.
func (s *Service) CreateFolder(ctx context.Context, p CreateFolderParams) (models.Node, error) {
	name := strings.TrimSpace(p.Name)
	if err := pathsafe.ValidateName(name); err != nil {
		return models.Node{}, fmt.Errorf("%w: %v", ErrInvalidName, err)
	}
	if p.Color != "" && !validColor(p.Color) {
		return models.Node{}, fmt.Errorf("%w: color", ErrInvalidName)
	}

	var created models.Node
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		ownerID := p.UserID
		libraryID := p.LibraryID
		parentID := ""

		if p.ParentID != "" && p.ParentID != "root" {
			parent, err := s.resolveTx(ctx, tx, p.UserID, p.ParentID, false)
			if err != nil {
				return err
			}
			if err := requireFolder(parent.Node); err != nil {
				return err
			}
			if err := parent.Require(CapCreate); err != nil {
				return err
			}
			parentID = parent.Node.ID
			libraryID = parent.Node.LibraryID
			ownerID = parent.Node.OwnerID
		} else {
			if libraryID == "" {
				def, err := s.libs.Default()
				if err != nil {
					return err
				}
				libraryID = def.ID
			}
			if _, err := s.libs.Root(libraryID); err != nil {
				return err
			}
		}

		unique, err := uniqueName(ctx, tx, parentID, ownerID, name, "")
		if err != nil {
			return err
		}
		now := db.NowMillis()
		created = models.Node{
			ID: db.NewID(), ParentID: parentID, OwnerID: ownerID, LibraryID: libraryID,
			Name: unique, Type: models.NodeFolder, Color: p.Color,
			VersionCount: 0, CreatedAt: now, UpdatedAt: now,
		}
		if err := insertNode(ctx, tx, created); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: p.UserID, NodeID: created.ID, Action: audit.ActionNodeCreated, IP: p.IP,
			Metadata: map[string]any{"name": unique, "type": "folder"},
		})
	})
	if err != nil {
		return models.Node{}, err
	}
	s.emit(ctx, ws.EventNodeCreated, created)
	return created, nil
}

// RenameParams describes a rename.
type RenameParams struct {
	UserID string
	NodeID string
	Name   string
	IP     string
}

// Rename changes a node's name. Editor and above.
func (s *Service) Rename(ctx context.Context, p RenameParams) (models.Node, error) {
	name := strings.TrimSpace(p.Name)
	if err := pathsafe.ValidateName(name); err != nil {
		return models.Node{}, fmt.Errorf("%w: %v", ErrInvalidName, err)
	}
	var updated models.Node
	var oldName string
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, p.UserID, p.NodeID, false)
		if err != nil {
			return err
		}
		if err := acc.Require(CapRename); err != nil {
			return err
		}
		oldName = acc.Node.Name
		unique, err := uniqueName(ctx, tx, acc.Node.ParentID, acc.Node.OwnerID, name, acc.Node.ID)
		if err != nil {
			return err
		}
		now := db.NowMillis()
		if _, err := tx.ExecContext(ctx, `UPDATE nodes SET name = ?, updated_at = ? WHERE id = ?`,
			unique, now, acc.Node.ID); err != nil {
			return err
		}
		acc.Node.Name = unique
		acc.Node.UpdatedAt = now
		updated = acc.Node
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: p.UserID, NodeID: acc.Node.ID, Action: audit.ActionNodeRenamed, IP: p.IP,
			Metadata: map[string]any{"from": oldName, "to": unique},
		})
	})
	if err != nil {
		return models.Node{}, err
	}
	s.refreshMirror(ctx, updated, oldName)
	s.emit(ctx, ws.EventNodeUpdated, updated)
	return updated, nil
}

// MoveParams describes a move.
type MoveParams struct {
	UserID   string
	NodeID   string
	ParentID string // "" or "root" moves to the top level
	IP       string
}

// Move relocates a node inside its own library. Owner only, and a move that
// would cross a library boundary is refused here rather than silently copying.
func (s *Service) Move(ctx context.Context, p MoveParams) (models.Node, error) {
	var updated models.Node
	var oldParent string
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, p.UserID, p.NodeID, false)
		if err != nil {
			return err
		}
		if err := acc.Require(CapMove); err != nil {
			return err
		}
		oldParent = acc.Node.ParentID

		newParentID := ""
		if p.ParentID != "" && p.ParentID != "root" {
			parent, err := s.resolveTx(ctx, tx, p.UserID, p.ParentID, false)
			if err != nil {
				return err
			}
			if err := requireFolder(parent.Node); err != nil {
				return err
			}
			if err := parent.Require(CapCreate); err != nil {
				return err
			}
			if parent.Node.LibraryID != acc.Node.LibraryID {
				return ErrCrossLibrary
			}
			descendant, err := isDescendant(ctx, tx, acc.Node.ID, parent.Node.ID)
			if err != nil {
				return err
			}
			if descendant {
				return ErrCycle
			}
			newParentID = parent.Node.ID
		}
		if newParentID == acc.Node.ParentID {
			updated = acc.Node
			return nil
		}
		unique, err := uniqueName(ctx, tx, newParentID, acc.Node.OwnerID, acc.Node.Name, acc.Node.ID)
		if err != nil {
			return err
		}
		now := db.NowMillis()
		if _, err := tx.ExecContext(ctx,
			`UPDATE nodes SET parent_id = ?, name = ?, updated_at = ? WHERE id = ?`,
			db.NullString(newParentID), unique, now, acc.Node.ID); err != nil {
			return err
		}
		acc.Node.ParentID = newParentID
		acc.Node.Name = unique
		acc.Node.UpdatedAt = now
		updated = acc.Node
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: p.UserID, NodeID: acc.Node.ID, Action: audit.ActionNodeMoved, IP: p.IP,
			Metadata: map[string]any{"from_parent": oldParent, "to_parent": newParentID},
		})
	})
	if err != nil {
		return models.Node{}, err
	}
	s.rebuildOwnerMirror(ctx, updated.LibraryID, updated.OwnerID)
	s.emit(ctx, ws.EventNodeMoved, updated)
	return updated, nil
}

// Recolor sets a folder's color. Owner only, folders only.
func (s *Service) Recolor(ctx context.Context, userID, nodeID, color, ip string) (models.Node, error) {
	if color != "" && !validColor(color) {
		return models.Node{}, fmt.Errorf("%w: color", ErrInvalidName)
	}
	var updated models.Node
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, userID, nodeID, false)
		if err != nil {
			return err
		}
		if err := acc.Require(CapRecolor); err != nil {
			return err
		}
		if err := requireFolder(acc.Node); err != nil {
			return err
		}
		now := db.NowMillis()
		if _, err := tx.ExecContext(ctx, `UPDATE nodes SET color = ?, updated_at = ? WHERE id = ?`,
			db.NullString(color), now, acc.Node.ID); err != nil {
			return err
		}
		acc.Node.Color = color
		acc.Node.UpdatedAt = now
		updated = acc.Node
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, NodeID: nodeID, Action: audit.ActionNodeRecolored, IP: ip,
			Metadata: map[string]any{"color": color},
		})
	})
	if err != nil {
		return models.Node{}, err
	}
	s.emit(ctx, ws.EventNodeUpdated, updated)
	return updated, nil
}

// Star adds the caller's own bookmark. Viewer access is enough, and it is
// invisible to everyone else including the owner.
func (s *Service) Star(ctx context.Context, userID, nodeID string) error {
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, userID, nodeID, false)
		if err != nil {
			return err
		}
		if err := acc.Require(CapStar); err != nil {
			return err
		}
		_, err = tx.ExecContext(ctx,
			`INSERT INTO stars (user_id, node_id, created_at) VALUES (?, ?, ?)
			 ON CONFLICT (user_id, node_id) DO NOTHING`,
			userID, nodeID, db.NowMillis())
		return err
	})
}

// Unstar removes the caller's bookmark.
func (s *Service) Unstar(ctx context.Context, userID, nodeID string) error {
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `DELETE FROM stars WHERE user_id = ? AND node_id = ?`, userID, nodeID)
		return err
	})
}

// Trash moves a node and everything under it out of view. Owner only, and it
// hides the node from everyone it was shared with too.
func (s *Service) Trash(ctx context.Context, userID, nodeID, ip string) (models.Node, error) {
	var trashed models.Node
	var audience []string
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, userID, nodeID, false)
		if err != nil {
			return err
		}
		if err := acc.Require(CapTrash); err != nil {
			return err
		}
		audience, err = viewersWith(ctx, tx, nodeID)
		if err != nil {
			return err
		}
		now := db.NowMillis()
		if _, err := tx.ExecContext(ctx, `
			WITH RECURSIVE tree(id, depth) AS (
				SELECT id, 0 FROM nodes WHERE id = ?
				UNION ALL
				SELECT n.id, t.depth + 1 FROM nodes n JOIN tree t ON n.parent_id = t.id WHERE t.depth < 128
			)
			UPDATE nodes SET trashed_at = ?, updated_at = ?
			WHERE id IN (SELECT id FROM tree) AND trashed_at IS NULL AND deleted_at IS NULL`,
			nodeID, now, now); err != nil {
			return err
		}
		acc.Node.TrashedAt = now
		acc.Node.UpdatedAt = now
		trashed = acc.Node
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, NodeID: nodeID, Action: audit.ActionNodeTrashed, IP: ip,
			Metadata: map[string]any{"name": acc.Node.Name},
		})
	})
	if err != nil {
		return models.Node{}, err
	}
	s.removeFromMirror(ctx, trashed)
	s.hub.Publish(ws.NewEvent(ws.EventNodeDeleted, db.NowMillis(), nodePayload(trashed)), audience...)
	return trashed, nil
}

// Restore brings a trashed subtree back.
func (s *Service) Restore(ctx context.Context, userID, nodeID, ip string) (models.Node, error) {
	var restored models.Node
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, userID, nodeID, true)
		if err != nil && !errors.Is(err, ErrTrashed) {
			return err
		}
		if err := acc.Require(CapTrash); err != nil {
			return err
		}
		if acc.Node.TrashedAt == 0 {
			restored = acc.Node
			return nil
		}
		// a node whose parent is still trashed cannot come back on its own
		if acc.Node.ParentID != "" {
			var parentTrashed sql.NullInt64
			err := tx.QueryRowContext(ctx, `SELECT trashed_at FROM nodes WHERE id = ?`, acc.Node.ParentID).Scan(&parentTrashed)
			if err != nil && !errors.Is(err, sql.ErrNoRows) {
				return err
			}
			if parentTrashed.Valid {
				return fmt.Errorf("%w: restore the folder it was in first", ErrConflict)
			}
		}
		now := db.NowMillis()
		unique, err := uniqueName(ctx, tx, acc.Node.ParentID, acc.Node.OwnerID, acc.Node.Name, acc.Node.ID)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `
			WITH RECURSIVE tree(id, depth) AS (
				SELECT id, 0 FROM nodes WHERE id = ?
				UNION ALL
				SELECT n.id, t.depth + 1 FROM nodes n JOIN tree t ON n.parent_id = t.id WHERE t.depth < 128
			)
			UPDATE nodes SET trashed_at = NULL, updated_at = ?
			WHERE id IN (SELECT id FROM tree) AND deleted_at IS NULL`,
			nodeID, now); err != nil {
			return err
		}
		if unique != acc.Node.Name {
			if _, err := tx.ExecContext(ctx, `UPDATE nodes SET name = ? WHERE id = ?`, unique, nodeID); err != nil {
				return err
			}
			acc.Node.Name = unique
		}
		acc.Node.TrashedAt = 0
		acc.Node.UpdatedAt = now
		restored = acc.Node
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, NodeID: nodeID, Action: audit.ActionNodeRestored, IP: ip,
			Metadata: map[string]any{"name": acc.Node.Name},
		})
	})
	if err != nil {
		return models.Node{}, err
	}
	s.rebuildOwnerMirror(ctx, restored.LibraryID, restored.OwnerID)
	s.emit(ctx, ws.EventNodeRestored, restored)
	return restored, nil
}

// PermanentDelete removes a subtree for good, freeing every object no other
// node or version still references.
func (s *Service) PermanentDelete(ctx context.Context, userID, nodeID, ip string) error {
	var (
		root      models.Node
		audience  []string
		orphans   []orphanObject
		freedSize int64
	)
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, userID, nodeID, true)
		if err != nil && !errors.Is(err, ErrTrashed) {
			return err
		}
		if err := acc.Require(CapTrash); err != nil {
			return err
		}
		root = acc.Node
		audience, err = viewersWith(ctx, tx, nodeID)
		if err != nil {
			return err
		}
		subtree, err := descendantIDs(ctx, tx, nodeID)
		if err != nil {
			return err
		}
		orphans = orphans[:0]
		for _, n := range subtree {
			if n.Type == models.NodeFile && n.ChecksumSHA256 != "" {
				refs, err := objectReferences(ctx, tx, n.LibraryID, n.ChecksumSHA256, n.ID, true)
				if err != nil {
					return err
				}
				if refs == 0 {
					orphans = append(orphans, orphanObject{LibraryID: n.LibraryID, Checksum: n.ChecksumSHA256})
				}
				freedSize += n.SizeBytes
			}
			orphans = append(orphans, orphanObject{LibraryID: n.LibraryID, ThumbnailFor: n.ID})
		}
		// versions of the deleted files release their objects too
		versionRows, err := tx.QueryContext(ctx, `
			WITH RECURSIVE tree(id, depth) AS (
				SELECT id, 0 FROM nodes WHERE id = ?
				UNION ALL
				SELECT n.id, t.depth + 1 FROM nodes n JOIN tree t ON n.parent_id = t.id WHERE t.depth < 128
			)
			SELECT v.checksum_sha256, n.library_id FROM node_versions v
			JOIN nodes n ON n.id = v.node_id
			WHERE v.node_id IN (SELECT id FROM tree)`, nodeID)
		if err != nil {
			return err
		}
		var versionObjects []orphanObject
		for versionRows.Next() {
			var sum, lib string
			if err := versionRows.Scan(&sum, &lib); err != nil {
				versionRows.Close()
				return err
			}
			versionObjects = append(versionObjects, orphanObject{LibraryID: lib, Checksum: sum})
		}
		versionRows.Close()
		if err := versionRows.Err(); err != nil {
			return err
		}

		if _, err := tx.ExecContext(ctx, `DELETE FROM nodes WHERE id = ?`, nodeID); err != nil {
			return err
		}
		// cascade removes descendants, versions, stars, permissions and shares
		for _, obj := range versionObjects {
			var stillUsed int
			err := tx.QueryRowContext(ctx, `
				SELECT (SELECT COUNT(*) FROM nodes WHERE checksum_sha256 = ? AND library_id = ? AND deleted_at IS NULL)
				     + (SELECT COUNT(*) FROM node_versions v JOIN nodes n ON n.id = v.node_id
				         WHERE v.checksum_sha256 = ? AND n.library_id = ?)`,
				obj.Checksum, obj.LibraryID, obj.Checksum, obj.LibraryID).Scan(&stillUsed)
			if err != nil {
				return err
			}
			if stillUsed == 0 {
				orphans = append(orphans, obj)
			}
		}
		if err := addQuotaTx(ctx, tx, root.OwnerID, -freedSize); err != nil {
			return err
		}
		if err := libraries.AddBytesTx(ctx, tx, root.LibraryID, -freedSize); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, NodeID: nodeID, Action: audit.ActionNodeDeleted, IP: ip,
			Metadata: map[string]any{"name": root.Name, "freed_bytes": freedSize},
		})
	})
	if err != nil {
		return err
	}

	s.removeFromMirror(ctx, root)
	s.pool.Submit(jobs.Job{Kind: jobs.KindTrashPurge, Name: "release objects", Run: func(ctx context.Context) error {
		s.releaseObjects(orphans)
		return nil
	}})
	s.hub.Publish(ws.NewEvent(ws.EventNodeDeleted, db.NowMillis(), nodePayload(root)), audience...)
	s.publishQuota(ctx, root.OwnerID)
	return nil
}

type orphanObject struct {
	LibraryID    string
	Checksum     string
	ThumbnailFor string
}

func (s *Service) releaseObjects(list []orphanObject) {
	for _, obj := range list {
		root, err := s.libs.Root(obj.LibraryID)
		if err != nil {
			continue
		}
		if obj.ThumbnailFor != "" {
			if err := s.store.RemoveThumbnail(root, obj.ThumbnailFor); err != nil {
				s.log.Debug("thumbnail removal failed", "node", obj.ThumbnailFor, "error", err)
			}
			continue
		}
		if err := s.store.Remove(root, obj.Checksum); err != nil {
			s.log.Warn("object removal failed", "checksum", obj.Checksum, "error", err)
		}
	}
}

// PrepareUpload validates an upload before a single byte is accepted: the
// caller's access to the destination, the library it lands in, and whether it
// fits the owner's quota. Failing here means a client is told no at creation
// time rather than after a long transfer.
func (s *Service) PrepareUpload(ctx context.Context, userID, parentID, nodeID string, size int64) (libraryID, ownerID string, err error) {
	if nodeID != "" {
		acc, err := s.Resolve(ctx, userID, nodeID)
		if err != nil {
			return "", "", err
		}
		if err := acc.Require(CapUploadVersion); err != nil {
			return "", "", err
		}
		if acc.Node.IsFolder() {
			return "", "", ErrNotAFile
		}
		if err := s.checkQuota(ctx, acc.Node.OwnerID, size-acc.Node.SizeBytes); err != nil {
			return "", "", err
		}
		return acc.Node.LibraryID, acc.Node.OwnerID, nil
	}

	ownerID = userID
	if parentID != "" && parentID != "root" {
		parent, err := s.Resolve(ctx, userID, parentID)
		if err != nil {
			return "", "", err
		}
		if err := requireFolder(parent.Node); err != nil {
			return "", "", err
		}
		if err := parent.Require(CapCreate); err != nil {
			return "", "", err
		}
		libraryID = parent.Node.LibraryID
		ownerID = parent.Node.OwnerID
	} else {
		def, err := s.libs.Default()
		if err != nil {
			return "", "", err
		}
		libraryID = def.ID
	}
	if err := s.checkQuota(ctx, ownerID, size); err != nil {
		return "", "", err
	}
	return libraryID, ownerID, nil
}

func (s *Service) checkQuota(ctx context.Context, ownerID string, delta int64) error {
	if delta <= 0 {
		return nil
	}
	var quota, used int64
	err := s.database.Read().QueryRowContext(ctx,
		`SELECT quota_bytes, quota_bytes_used FROM users WHERE id = ?`, ownerID).Scan(&quota, &used)
	if err != nil {
		return err
	}
	if quota <= 0 {
		return nil
	}
	if used+delta > quota {
		return fmt.Errorf("%w: %d bytes needed, %d available", ErrQuota, delta, quota-used)
	}
	return nil
}

// CommitUploadParams is one finished upload ready to become a node.
type CommitUploadParams struct {
	UserID   string
	ParentID string
	Name     string
	MimeType string
	Size     int64
	Checksum string
	TempPath string // already-written bytes, adopted into the object store
	NodeID   string // set to replace an existing file with a new version
	IP       string
}

// CommitUpload turns finished bytes into a node, or into a new version of an
// existing one. The object is adopted into the content-addressed store first,
// so the database never references bytes that are not on disk yet.
func (s *Service) CommitUpload(ctx context.Context, p CommitUploadParams) (models.Node, error) {
	name := strings.TrimSpace(p.Name)
	if err := pathsafe.ValidateName(name); err != nil {
		return models.Node{}, fmt.Errorf("%w: %v", ErrInvalidName, err)
	}

	var (
		result    models.Node
		isNew     bool
		replaced  string
		libraryID string
		ownerID   string
		sizeDelta int64
	)

	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		if p.NodeID != "" {
			acc, err := s.resolveTx(ctx, tx, p.UserID, p.NodeID, false)
			if err != nil {
				return err
			}
			if err := acc.Require(CapUploadVersion); err != nil {
				return err
			}
			if acc.Node.IsFolder() {
				return ErrNotAFile
			}
			libraryID = acc.Node.LibraryID
			ownerID = acc.Node.OwnerID
			sizeDelta = p.Size - acc.Node.SizeBytes
			if err := checkQuotaTx(ctx, tx, ownerID, sizeDelta); err != nil {
				return err
			}
			now := db.NowMillis()
			// keep the outgoing bytes as a version before overwriting
			if acc.Node.ChecksumSHA256 != "" && acc.Node.ChecksumSHA256 != p.Checksum {
				if _, err := tx.ExecContext(ctx, `
					INSERT INTO node_versions (id, node_id, size_bytes, checksum_sha256, mime_type, created_by, created_at)
					VALUES (?, ?, ?, ?, ?, ?, ?)`,
					db.NewID(), acc.Node.ID, acc.Node.SizeBytes, acc.Node.ChecksumSHA256,
					acc.Node.MimeType, db.NullString(p.UserID), now); err != nil {
					return err
				}
			}
			replaced = acc.Node.ChecksumSHA256
			if _, err := tx.ExecContext(ctx, `
				UPDATE nodes SET size_bytes = ?, checksum_sha256 = ?, mime_type = ?,
				                 has_thumbnail = 0, thumbnail_generated_at = NULL,
				                 version_count = version_count + 1, updated_at = ?
				WHERE id = ?`,
				p.Size, p.Checksum, p.MimeType, now, acc.Node.ID); err != nil {
				return err
			}
			acc.Node.SizeBytes = p.Size
			acc.Node.ChecksumSHA256 = p.Checksum
			acc.Node.MimeType = p.MimeType
			acc.Node.HasThumbnail = false
			acc.Node.UpdatedAt = now
			acc.Node.VersionCount++
			result = acc.Node
		} else {
			parentID := ""
			ownerID = p.UserID
			if p.ParentID != "" && p.ParentID != "root" {
				parent, err := s.resolveTx(ctx, tx, p.UserID, p.ParentID, false)
				if err != nil {
					return err
				}
				if err := requireFolder(parent.Node); err != nil {
					return err
				}
				if err := parent.Require(CapCreate); err != nil {
					return err
				}
				parentID = parent.Node.ID
				libraryID = parent.Node.LibraryID
				ownerID = parent.Node.OwnerID
			} else {
				def, err := s.libs.Default()
				if err != nil {
					return err
				}
				libraryID = def.ID
			}
			sizeDelta = p.Size
			if err := checkQuotaTx(ctx, tx, ownerID, sizeDelta); err != nil {
				return err
			}
			unique, err := uniqueName(ctx, tx, parentID, ownerID, name, "")
			if err != nil {
				return err
			}
			now := db.NowMillis()
			result = models.Node{
				ID: db.NewID(), ParentID: parentID, OwnerID: ownerID, LibraryID: libraryID,
				Name: unique, Type: models.NodeFile, MimeType: p.MimeType, SizeBytes: p.Size,
				ChecksumSHA256: p.Checksum, VersionCount: 1, CreatedAt: now, UpdatedAt: now,
			}
			if err := insertNode(ctx, tx, result); err != nil {
				return err
			}
			isNew = true
		}

		if err := addQuotaTx(ctx, tx, ownerID, sizeDelta); err != nil {
			return err
		}
		if err := libraries.AddBytesTx(ctx, tx, libraryID, sizeDelta); err != nil {
			return err
		}
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: p.UserID, NodeID: result.ID, Action: audit.ActionNodeUploaded, IP: p.IP,
			Metadata: map[string]any{"name": result.Name, "size": p.Size, "new": isNew},
		})
	})
	if err != nil {
		return models.Node{}, err
	}

	// the replaced object is only removed once nothing references it
	if replaced != "" && replaced != p.Checksum {
		s.maybeRelease(ctx, libraryID, replaced, result.ID)
	}
	s.addToMirror(ctx, result)

	// The thumbnail and checksum jobs are deliberately not started here. The
	// caller adopts the uploaded bytes into storage after this returns, so a
	// job queued now races that and usually loses: it opens an object that is
	// not there yet, fails with "object not found", and is never retried. The
	// file ends up fine and permanently without a preview. The caller starts
	// them with ScheduleDerived once the bytes are in place.
	if isNew {
		s.emit(ctx, ws.EventNodeCreated, result)
	} else {
		s.emit(ctx, ws.EventNodeUpdated, result)
	}
	s.publishQuota(ctx, ownerID)
	return result, nil
}

// AdoptObject moves finished upload bytes into the object store for a library.
func (s *Service) AdoptObject(libraryID, tempPath, sum string) error {
	root, err := s.libs.Root(libraryID)
	if err != nil {
		return err
	}
	return s.store.Adopt(root, tempPath, sum)
}

func (s *Service) maybeRelease(ctx context.Context, libraryID, sum, excludeNodeID string) {
	refs, err := objectReferences(ctx, s.database.Read(), libraryID, sum, excludeNodeID, false)
	if err != nil || refs > 0 {
		return
	}
	if root, err := s.libs.Root(libraryID); err == nil {
		_ = s.store.Remove(root, sum)
	}
}

// Versions lists a file's history, newest first.
func (s *Service) Versions(ctx context.Context, userID, nodeID string) ([]models.NodeVersion, error) {
	acc, err := s.Resolve(ctx, userID, nodeID)
	if err != nil {
		return nil, err
	}
	if err := acc.Require(CapBrowse); err != nil {
		return nil, err
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT id, node_id, size_bytes, checksum_sha256, mime_type, created_by, created_at
		FROM node_versions WHERE node_id = ? ORDER BY created_at DESC`, nodeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.NodeVersion
	for rows.Next() {
		var v models.NodeVersion
		var createdBy sql.NullString
		if err := rows.Scan(&v.ID, &v.NodeID, &v.SizeBytes, &v.ChecksumSHA256, &v.MimeType, &createdBy, &v.CreatedAt); err != nil {
			return nil, err
		}
		v.CreatedBy = db.StringOrEmpty(createdBy)
		out = append(out, v)
	}
	return out, rows.Err()
}

// RestoreVersion swaps a file back to an earlier state, keeping the current
// bytes as a new version so the move is itself reversible.
func (s *Service) RestoreVersion(ctx context.Context, userID, nodeID, versionID, ip string) (models.Node, error) {
	var (
		result    models.Node
		ownerID   string
		libraryID string
	)
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		acc, err := s.resolveTx(ctx, tx, userID, nodeID, false)
		if err != nil {
			return err
		}
		if err := acc.Require(CapUploadVersion); err != nil {
			return err
		}
		var v models.NodeVersion
		var createdBy sql.NullString
		err = tx.QueryRowContext(ctx, `
			SELECT id, node_id, size_bytes, checksum_sha256, mime_type, created_by, created_at
			FROM node_versions WHERE id = ? AND node_id = ?`, versionID, nodeID).
			Scan(&v.ID, &v.NodeID, &v.SizeBytes, &v.ChecksumSHA256, &v.MimeType, &createdBy, &v.CreatedAt)
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotFound
		}
		if err != nil {
			return err
		}

		ownerID = acc.Node.OwnerID
		libraryID = acc.Node.LibraryID
		delta := v.SizeBytes - acc.Node.SizeBytes
		if err := checkQuotaTx(ctx, tx, ownerID, delta); err != nil {
			return err
		}
		now := db.NowMillis()
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO node_versions (id, node_id, size_bytes, checksum_sha256, mime_type, created_by, created_at)
			VALUES (?, ?, ?, ?, ?, ?, ?)`,
			db.NewID(), nodeID, acc.Node.SizeBytes, acc.Node.ChecksumSHA256, acc.Node.MimeType,
			db.NullString(userID), now); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE nodes SET size_bytes = ?, checksum_sha256 = ?, mime_type = ?,
			                 has_thumbnail = 0, thumbnail_generated_at = NULL,
			                 version_count = version_count + 1, updated_at = ?
			WHERE id = ?`, v.SizeBytes, v.ChecksumSHA256, v.MimeType, now, nodeID); err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, `DELETE FROM node_versions WHERE id = ?`, versionID); err != nil {
			return err
		}
		if err := addQuotaTx(ctx, tx, ownerID, delta); err != nil {
			return err
		}
		if err := libraries.AddBytesTx(ctx, tx, libraryID, delta); err != nil {
			return err
		}
		acc.Node.SizeBytes = v.SizeBytes
		acc.Node.ChecksumSHA256 = v.ChecksumSHA256
		acc.Node.MimeType = v.MimeType
		acc.Node.HasThumbnail = false
		acc.Node.UpdatedAt = now
		acc.Node.VersionCount++
		result = acc.Node
		return s.audit.RecordTx(ctx, tx, audit.Entry{
			UserID: userID, NodeID: nodeID, Action: audit.ActionVersionRestored, IP: ip,
			Metadata: map[string]any{"version": versionID},
		})
	})
	if err != nil {
		return models.Node{}, err
	}
	s.addToMirror(ctx, result)
	s.scheduleThumbnail(result)
	s.emit(ctx, ws.EventNodeUpdated, result)
	s.publishQuota(ctx, ownerID)
	return result, nil
}

// SetMediaInfo records what an image says about itself.
//
// Written whether or not a thumbnail was produced: a picture too odd to render
// a preview for still has dimensions and a capture time worth knowing, and a
// gallery laid out without them reflows as images arrive.
func (s *Service) SetMediaInfo(ctx context.Context, nodeID string, width, height int, takenAt int64) error {
	return s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx,
			`UPDATE nodes SET image_width = ?, image_height = ?, taken_at = ? WHERE id = ?`,
			width, height, db.NullInt64(takenAt), nodeID)
		return err
	})
}

// SetThumbnailReady records a generated preview and tells open clients.
func (s *Service) SetThumbnailReady(ctx context.Context, nodeID string) error {
	now := db.NowMillis()
	err := s.database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx,
			`UPDATE nodes SET has_thumbnail = 1, thumbnail_generated_at = ? WHERE id = ?`, now, nodeID)
		return err
	})
	if err != nil {
		return err
	}
	node, err := s.GetNode(ctx, nodeID)
	if err != nil {
		return err
	}
	node.HasThumbnail = true
	node.ThumbnailGeneratedAt = now
	s.emit(ctx, ws.EventNodeThumbnail, node)
	return nil
}

// ScheduleDerived starts the work that reads the stored object: the preview
// and the checksum verification.
//
// Separate from CommitUpload because the row and the bytes land in that order,
// and both of these need the bytes. Calling it before the object is adopted
// queues work that fails immediately.
func (s *Service) ScheduleDerived(node models.Node) {
	s.scheduleThumbnail(node)
	s.scheduleVerify(node)
}

func (s *Service) scheduleThumbnail(node models.Node) {
	if s.thumbnailer == nil || node.Type != models.NodeFile {
		return
	}
	s.pool.Submit(jobs.Job{Kind: jobs.KindThumbnail, Name: node.ID, Run: func(ctx context.Context) error {
		root, err := s.libs.Root(node.LibraryID)
		if err != nil {
			return err
		}

		// dimensions and capture time first, and independently: a picture the
		// thumbnailer cannot render still has both, and a gallery needs them
		// more than it needs the preview
		if s.mediaProbe != nil {
			if path, err := s.store.ObjectPath(root, node.ChecksumSHA256); err == nil {
				if width, height, takenAt, err := s.mediaProbe(path); err == nil {
					_ = s.SetMediaInfo(ctx, node.ID, width, height, takenAt)
				}
			}
		}

		if err := s.thumbnailer(ctx, node, root); err != nil {
			return err
		}
		return s.SetThumbnailReady(ctx, node.ID)
	}})
}

func (s *Service) scheduleVerify(node models.Node) {
	s.pool.Submit(jobs.Job{Kind: jobs.KindVerify, Name: node.ID, Run: func(ctx context.Context) error {
		root, err := s.libs.Root(node.LibraryID)
		if err != nil {
			return err
		}
		if err := s.store.Verify(root, node.ChecksumSHA256); err != nil {
			s.log.Error("uploaded object failed verification", "node", node.ID, "error", err)
			return err
		}
		return nil
	}})
}

func (s *Service) emit(ctx context.Context, eventType string, node models.Node) {
	audience, err := s.Viewers(ctx, node.ID)
	if err != nil || len(audience) == 0 {
		audience = []string{node.OwnerID}
	}
	s.hub.Publish(ws.NewEvent(eventType, db.NowMillis(), nodePayload(node)), audience...)
}

func (s *Service) publishQuota(ctx context.Context, userID string) {
	var quota, used int64
	err := s.database.Read().QueryRowContext(ctx,
		`SELECT quota_bytes, quota_bytes_used FROM users WHERE id = ?`, userID).Scan(&quota, &used)
	if err != nil {
		return
	}
	s.hub.Publish(ws.NewEvent(ws.EventQuotaUpdated, db.NowMillis(), map[string]any{
		"quota_bytes": quota, "quota_bytes_used": used,
	}), userID)
}

func nodePayload(n models.Node) map[string]any {
	return map[string]any{
		"id":         n.ID,
		"parent_id":  n.ParentID,
		"owner_id":   n.OwnerID,
		"library_id": n.LibraryID,
		"name":       n.Name,
		"type":       string(n.Type),
		"mime_type":  n.MimeType,
		"size_bytes": n.SizeBytes,
		"updated_at": n.UpdatedAt,
	}
}

// mirror maintenance, all best effort and off the request path

func (s *Service) addToMirror(ctx context.Context, node models.Node) {
	if s.mirror == nil || s.mirror.Disabled() || node.Type != models.NodeFile {
		return
	}
	s.pool.Submit(jobs.Job{Kind: jobs.KindMirror, Name: node.ID, Run: func(ctx context.Context) error {
		root, err := s.libs.Root(node.LibraryID)
		if err != nil {
			return err
		}
		owner, rel, err := s.mirrorLocation(ctx, node)
		if err != nil {
			return err
		}
		s.mirror.Link(root, storage.MirrorEntry{
			Owner: owner, RelPath: rel, Name: node.Name, Checksum: node.ChecksumSHA256,
		})
		return nil
	}})
}

func (s *Service) removeFromMirror(ctx context.Context, node models.Node) {
	if s.mirror == nil || s.mirror.Disabled() {
		return
	}
	s.rebuildOwnerMirror(ctx, node.LibraryID, node.OwnerID)
}

func (s *Service) refreshMirror(ctx context.Context, node models.Node, oldName string) {
	if s.mirror == nil || s.mirror.Disabled() {
		return
	}
	s.rebuildOwnerMirror(ctx, node.LibraryID, node.OwnerID)
}

// rebuildOwnerMirror redraws one person's browse subtree. Structural changes
// are rare and the tree is small, so a rebuild is simpler and more correct
// than trying to patch individual links.
func (s *Service) rebuildOwnerMirror(ctx context.Context, libraryID, ownerID string) {
	if s.mirror == nil || s.mirror.Disabled() {
		return
	}
	s.pool.Submit(jobs.Job{Kind: jobs.KindMirror, Name: "rebuild " + ownerID, Run: func(ctx context.Context) error {
		root, err := s.libs.Root(libraryID)
		if err != nil {
			return err
		}
		ownerName, err := s.ownerName(ctx, ownerID)
		if err != nil {
			return err
		}
		rows, err := s.database.Read().QueryContext(ctx, `
			SELECT id, name, checksum_sha256 FROM nodes
			WHERE owner_id = ? AND library_id = ? AND type = 'file'
			  AND deleted_at IS NULL AND trashed_at IS NULL AND checksum_sha256 IS NOT NULL`,
			ownerID, libraryID)
		if err != nil {
			return err
		}
		defer rows.Close()
		var entries []storage.MirrorEntry
		for rows.Next() {
			var id, name, sum string
			if err := rows.Scan(&id, &name, &sum); err != nil {
				return err
			}
			rel, err := relPathOf(ctx, s.database.Read(), id)
			if err != nil {
				return err
			}
			if len(rel) > 0 {
				rel = rel[:len(rel)-1] // drop the file's own name
			}
			entries = append(entries, storage.MirrorEntry{
				Owner: ownerName, RelPath: rel, Name: name, Checksum: sum,
			})
		}
		if err := rows.Err(); err != nil {
			return err
		}
		s.mirror.Rebuild(root, ownerName, entries)
		return nil
	}})
}

func (s *Service) mirrorLocation(ctx context.Context, node models.Node) (owner string, rel []string, err error) {
	owner, err = s.ownerName(ctx, node.OwnerID)
	if err != nil {
		return "", nil, err
	}
	rel, err = relPathOf(ctx, s.database.Read(), node.ID)
	if err != nil {
		return "", nil, err
	}
	if len(rel) > 0 {
		rel = rel[:len(rel)-1]
	}
	return owner, rel, nil
}

func (s *Service) ownerName(ctx context.Context, ownerID string) (string, error) {
	var username string
	err := s.database.Read().QueryRowContext(ctx, `SELECT username FROM users WHERE id = ?`, ownerID).Scan(&username)
	return username, err
}

var folderColors = map[string]struct{}{
	"blue": {}, "green": {}, "orange": {}, "red": {}, "purple": {}, "teal": {}, "neutral": {},
}

func validColor(c string) bool {
	_, ok := folderColors[c]
	return ok
}
