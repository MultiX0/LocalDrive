package files

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/MultiX0/LocalDrive/server/internal/models"
)

// Errors this package returns. NotFound is deliberately what a caller with no
// access gets, so a stranger cannot even confirm a node exists.
var (
	ErrNotFound     = errors.New("files: node not found")
	ErrForbidden    = errors.New("files: not allowed")
	ErrInvalidName  = errors.New("files: invalid name")
	ErrNotAFolder   = errors.New("files: parent is not a folder")
	ErrNotAFile     = errors.New("files: node is not a file")
	ErrQuota        = errors.New("files: quota exceeded")
	ErrCycle        = errors.New("files: a folder cannot be moved inside itself")
	ErrCrossLibrary = errors.New("files: that move crosses a library boundary")
	ErrConflict     = errors.New("files: conflicting change")
	ErrTrashed      = errors.New("files: node is in the trash")
)

// Capability is one thing a caller may want to do to a node.
type Capability int

// The capability matrix from the plan, enforced server-side on every mutating
// request no matter which client is asking.
const (
	CapBrowse Capability = iota
	CapStar
	CapCreate
	CapRename
	CapUploadVersion
	CapMove
	CapRecolor
	CapTrash
	CapShare
)

// Can reports whether a resolved role may perform a capability.
//
//	action                 viewer  editor  owner
//	browse/preview/download  yes     yes    yes
//	star (own bookmark)      yes     yes    yes
//	create inside            no      yes    yes
//	rename                   no      yes    yes
//	upload a new version     no      yes    yes
//	move                     no      no     yes
//	recolor (folders)        no      no     yes
//	trash/restore/delete     no      no     yes
//	sharing and permissions  no      no     yes
func Can(role models.AccessRole, cap Capability) bool {
	switch cap {
	case CapBrowse, CapStar:
		return role >= models.AccessViewer
	case CapCreate, CapRename, CapUploadVersion:
		return role >= models.AccessEditor
	case CapMove, CapRecolor, CapTrash, CapShare:
		return role >= models.AccessOwner
	default:
		return false
	}
}

// Access is the outcome of resolving one caller against one node.
type Access struct {
	Node    models.Node
	Role    models.AccessRole
	Trashed bool // this node or one of its ancestors is in the trash
}

// Require returns ErrForbidden unless the caller may do cap.
func (a Access) Require(cap Capability) error {
	if !Can(a.Role, cap) {
		return ErrForbidden
	}
	return nil
}

const chainCTE = `
WITH RECURSIVE chain(id, parent_id, owner_id, trashed_at, depth) AS (
	SELECT id, parent_id, owner_id, trashed_at, 0
	  FROM nodes WHERE id = ? AND deleted_at IS NULL
	UNION ALL
	SELECT n.id, n.parent_id, n.owner_id, n.trashed_at, c.depth + 1
	  FROM nodes n JOIN chain c ON n.id = c.parent_id
	 WHERE c.depth < 128 AND n.deleted_at IS NULL
)`

// Resolve loads a node and the caller's role on it. A caller with no access
// gets ErrNotFound, never ErrForbidden.
func (s *Service) Resolve(ctx context.Context, userID, nodeID string) (Access, error) {
	return s.resolveWith(ctx, s.database.Read(), userID, nodeID, false)
}

type queryer interface {
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
}

func (s *Service) resolveWith(ctx context.Context, q queryer, userID, nodeID string, allowTrashed bool) (Access, error) {
	node, err := getNode(ctx, q, nodeID)
	if err != nil {
		return Access{}, err
	}

	var (
		trashedCount int
		bestRole     sql.NullString
	)
	err = q.QueryRowContext(ctx, chainCTE+`
		SELECT
		  (SELECT COUNT(*) FROM chain WHERE trashed_at IS NOT NULL),
		  (SELECT p.role FROM permissions p JOIN chain c ON p.node_id = c.id
		    WHERE p.user_id = ?
		    ORDER BY CASE p.role WHEN 'editor' THEN 2 ELSE 1 END DESC LIMIT 1)`,
		nodeID, userID).Scan(&trashedCount, &bestRole)
	if err != nil {
		return Access{}, err
	}

	acc := Access{Node: node, Trashed: trashedCount > 0}
	switch {
	case node.OwnerID == userID:
		acc.Role = models.AccessOwner
	case bestRole.Valid && bestRole.String == "editor":
		acc.Role = models.AccessEditor
	case bestRole.Valid:
		acc.Role = models.AccessViewer
	default:
		return Access{}, ErrNotFound
	}

	// trashing hides a node from everyone it was shared with, not only the
	// owner, so a viewer never sees it at all
	if acc.Trashed && !allowTrashed {
		if acc.Role != models.AccessOwner {
			return Access{}, ErrNotFound
		}
		return acc, ErrTrashed
	}
	return acc, nil
}

// resolveTx is Resolve inside a write transaction, so a check and the change
// it guards happen against the same snapshot.
func (s *Service) resolveTx(ctx context.Context, tx *sql.Tx, userID, nodeID string, allowTrashed bool) (Access, error) {
	return s.resolveWith(ctx, tx, userID, nodeID, allowTrashed)
}

// Viewers returns every user id that can currently see a node: its owner plus
// anyone with a permission row on it or an ancestor. This is the audience for
// a websocket event about that node.
func (s *Service) Viewers(ctx context.Context, nodeID string) ([]string, error) {
	return viewersWith(ctx, s.database.Read(), nodeID)
}

func viewersWith(ctx context.Context, q queryer, nodeID string) ([]string, error) {
	rows, err := q.QueryContext(ctx, chainCTE+`
		SELECT owner_id FROM chain WHERE depth = 0
		UNION
		SELECT p.user_id FROM permissions p JOIN chain c ON p.node_id = c.id`, nodeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// PathTo returns the breadcrumb from the library root down to nodeID,
// including the node itself, ordered root first.
func (s *Service) PathTo(ctx context.Context, userID, nodeID string) ([]models.Node, error) {
	if _, err := s.Resolve(ctx, userID, nodeID); err != nil {
		return nil, err
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		WITH RECURSIVE chain(id, parent_id, depth) AS (
			SELECT id, parent_id, 0 FROM nodes WHERE id = ? AND deleted_at IS NULL
			UNION ALL
			SELECT n.id, n.parent_id, c.depth + 1 FROM nodes n JOIN chain c ON n.id = c.parent_id
			WHERE c.depth < 128 AND n.deleted_at IS NULL
		)
		SELECT n.id, n.parent_id, n.owner_id, n.library_id, n.name, n.type, n.mime_type,
		       n.size_bytes, n.checksum_sha256, n.color, n.has_thumbnail, n.thumbnail_generated_at,
		       n.version_count, n.image_width, n.image_height, n.taken_at,
		       n.created_at, n.updated_at, n.trashed_at, n.deleted_at
		FROM nodes n JOIN chain c ON n.id = c.id
		ORDER BY c.depth DESC`, nodeID)
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

// isDescendant reports whether candidate sits anywhere under ancestor. Used to
// refuse moving a folder into itself.
func isDescendant(ctx context.Context, q queryer, ancestorID, candidateID string) (bool, error) {
	if ancestorID == candidateID {
		return true, nil
	}
	var hit int
	err := q.QueryRowContext(ctx, chainCTE+`
		SELECT COUNT(*) FROM chain WHERE id = ?`, candidateID, ancestorID).Scan(&hit)
	if err != nil {
		return false, err
	}
	return hit > 0, nil
}

func requireFolder(n models.Node) error {
	if !n.IsFolder() {
		return fmt.Errorf("%w: %s", ErrNotAFolder, n.Name)
	}
	return nil
}
