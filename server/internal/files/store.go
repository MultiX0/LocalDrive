package files

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"path"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

const nodeColumns = `id, parent_id, owner_id, library_id, name, type, mime_type, size_bytes,
	checksum_sha256, color, has_thumbnail, thumbnail_generated_at, version_count,
	image_width, image_height, taken_at,
	created_at, updated_at, trashed_at, deleted_at`

type rowScanner interface {
	Scan(dest ...any) error
}

func scanNode(row rowScanner) (models.Node, error) {
	var (
		n                  models.Node
		parentID, checksum sql.NullString
		color              sql.NullString
		hasThumb           int
		thumbAt, trashedAt sql.NullInt64
		deletedAt, takenAt sql.NullInt64
		nodeType           string
	)
	err := row.Scan(&n.ID, &parentID, &n.OwnerID, &n.LibraryID, &n.Name, &nodeType, &n.MimeType,
		&n.SizeBytes, &checksum, &color, &hasThumb, &thumbAt, &n.VersionCount,
		&n.ImageWidth, &n.ImageHeight, &takenAt,
		&n.CreatedAt, &n.UpdatedAt, &trashedAt, &deletedAt)
	if err != nil {
		return models.Node{}, err
	}
	n.Type = models.NodeType(nodeType)
	n.ParentID = db.StringOrEmpty(parentID)
	n.ChecksumSHA256 = db.StringOrEmpty(checksum)
	n.Color = db.StringOrEmpty(color)
	n.HasThumbnail = hasThumb != 0
	n.ThumbnailGeneratedAt = db.Int64OrZero(thumbAt)
	n.TakenAt = db.Int64OrZero(takenAt)
	n.TrashedAt = db.Int64OrZero(trashedAt)
	n.DeletedAt = db.Int64OrZero(deletedAt)
	return n, nil
}

func getNode(ctx context.Context, q queryer, id string) (models.Node, error) {
	row := q.QueryRowContext(ctx, `SELECT `+nodeColumns+` FROM nodes WHERE id = ? AND deleted_at IS NULL`, id)
	n, err := scanNode(row)
	if errors.Is(err, sql.ErrNoRows) {
		return models.Node{}, ErrNotFound
	}
	return n, err
}

func insertNode(ctx context.Context, tx *sql.Tx, n models.Node) error {
	_, err := tx.ExecContext(ctx, `
		INSERT INTO nodes (id, parent_id, owner_id, library_id, name, type, mime_type, size_bytes,
		                   checksum_sha256, color, has_thumbnail, thumbnail_generated_at,
		                   version_count, created_at, updated_at, trashed_at, deleted_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, NULL, NULL)`,
		n.ID, db.NullString(n.ParentID), n.OwnerID, n.LibraryID, n.Name, string(n.Type), n.MimeType,
		n.SizeBytes, db.NullString(n.ChecksumSHA256), db.NullString(n.Color),
		boolInt(n.HasThumbnail), n.VersionCount, n.CreatedAt, n.UpdatedAt)
	return err
}

// uniqueName resolves a name collision inside one parent the way a desktop
// file manager does, appending " (2)", " (3)" and so on before the extension.
func uniqueName(ctx context.Context, q queryer, parentID, ownerID, name string, excludeID string) (string, error) {
	taken, err := siblingNames(ctx, q, parentID, ownerID, excludeID)
	if err != nil {
		return "", err
	}
	if _, clash := taken[strings.ToLower(name)]; !clash {
		return name, nil
	}
	ext := path.Ext(name)
	base := strings.TrimSuffix(name, ext)
	for i := 2; i < 10000; i++ {
		candidate := fmt.Sprintf("%s (%d)%s", base, i, ext)
		if _, clash := taken[strings.ToLower(candidate)]; !clash {
			return candidate, nil
		}
	}
	return "", ErrConflict
}

func siblingNames(ctx context.Context, q queryer, parentID, ownerID, excludeID string) (map[string]struct{}, error) {
	var (
		rows *sql.Rows
		err  error
	)
	if parentID == "" {
		rows, err = q.QueryContext(ctx, `
			SELECT name FROM nodes
			WHERE parent_id IS NULL AND owner_id = ? AND deleted_at IS NULL AND trashed_at IS NULL AND id != ?`,
			ownerID, excludeID)
	} else {
		rows, err = q.QueryContext(ctx, `
			SELECT name FROM nodes
			WHERE parent_id = ? AND deleted_at IS NULL AND trashed_at IS NULL AND id != ?`,
			parentID, excludeID)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]struct{}{}
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		out[strings.ToLower(name)] = struct{}{}
	}
	return out, rows.Err()
}

// addQuotaTx moves a user's running usage counter, in the same transaction as
// the content change that caused it.
func addQuotaTx(ctx context.Context, tx *sql.Tx, userID string, delta int64) error {
	_, err := tx.ExecContext(ctx,
		`UPDATE users SET quota_bytes_used = MAX(0, quota_bytes_used + ?), updated_at = ? WHERE id = ?`,
		delta, db.NowMillis(), userID)
	return err
}

// checkQuotaTx refuses a write that would take an owner past their quota. A
// quota of zero means unlimited.
func checkQuotaTx(ctx context.Context, tx *sql.Tx, ownerID string, delta int64) error {
	if delta <= 0 {
		return nil
	}
	var quota, used int64
	err := tx.QueryRowContext(ctx, `SELECT quota_bytes, quota_bytes_used FROM users WHERE id = ?`, ownerID).Scan(&quota, &used)
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

// objectReferences counts how many live nodes and versions still point at one
// checksum, which makes deduplicated deletion safe.
//
// excludeNodeID drops one node from the node count. excludeOwnVersions also
// drops that node's version rows, which is only correct when the node and its
// whole history are going away; a node that merely replaced its current bytes
// still has versions pointing at the old object and must keep them.
func objectReferences(ctx context.Context, q queryer, libraryID, sum, excludeNodeID string, excludeOwnVersions bool) (int, error) {
	var nodeRefs, versionRefs int
	err := q.QueryRowContext(ctx, `
		SELECT COUNT(*) FROM nodes
		WHERE checksum_sha256 = ? AND library_id = ? AND deleted_at IS NULL AND id != ?`,
		sum, libraryID, excludeNodeID).Scan(&nodeRefs)
	if err != nil {
		return 0, err
	}
	versionQuery := `
		SELECT COUNT(*) FROM node_versions v JOIN nodes n ON n.id = v.node_id
		WHERE v.checksum_sha256 = ? AND n.library_id = ? AND n.deleted_at IS NULL`
	args := []any{sum, libraryID}
	if excludeOwnVersions {
		versionQuery += ` AND n.id != ?`
		args = append(args, excludeNodeID)
	}
	if err := q.QueryRowContext(ctx, versionQuery, args...).Scan(&versionRefs); err != nil {
		return 0, err
	}
	return nodeRefs + versionRefs, nil
}

// descendantIDs returns a folder and everything under it, deepest first, so a
// caller can delete children before parents.
func descendantIDs(ctx context.Context, q queryer, rootID string) ([]models.Node, error) {
	rows, err := q.QueryContext(ctx, `
		WITH RECURSIVE tree(id, depth) AS (
			SELECT id, 0 FROM nodes WHERE id = ? AND deleted_at IS NULL
			UNION ALL
			SELECT n.id, t.depth + 1 FROM nodes n JOIN tree t ON n.parent_id = t.id
			WHERE t.depth < 128 AND n.deleted_at IS NULL
		)
		SELECT `+prefixColumns("n.")+`
		FROM nodes n JOIN tree t ON n.id = t.id
		ORDER BY t.depth DESC`, rootID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Node
	for rows.Next() {
		n, err := scanNode(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

func prefixColumns(prefix string) string {
	parts := strings.Split(nodeColumns, ",")
	for i := range parts {
		parts[i] = prefix + strings.TrimSpace(parts[i])
	}
	return strings.Join(parts, ", ")
}

// relPathOf returns a node's folder names from the owner root down, used by
// the browse mirror.
func relPathOf(ctx context.Context, q queryer, nodeID string) ([]string, error) {
	rows, err := q.QueryContext(ctx, `
		WITH RECURSIVE chain(id, parent_id, name, depth) AS (
			SELECT id, parent_id, name, 0 FROM nodes WHERE id = ? AND deleted_at IS NULL
			UNION ALL
			SELECT n.id, n.parent_id, n.name, c.depth + 1 FROM nodes n JOIN chain c ON n.id = c.parent_id
			WHERE c.depth < 128 AND n.deleted_at IS NULL
		)
		SELECT name FROM chain ORDER BY depth DESC`, nodeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		out = append(out, name)
	}
	return out, rows.Err()
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
