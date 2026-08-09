package files

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/jobs"
	"github.com/MultiX0/LocalDrive/server/internal/libraries"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/settings"
	"github.com/MultiX0/LocalDrive/server/internal/storage"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

// Service owns the node tree: listing, creating, moving, trashing, and the
// version history behind every file.
type Service struct {
	database *db.DB
	store    *storage.Store
	mirror   *storage.Mirror
	libs     *libraries.Service
	hub      *ws.Hub
	audit    *audit.Logger
	pool     *jobs.Pool
	settings *settings.Service
	log      *slog.Logger

	// thumbnailer is set by the app wiring; nil means previews are skipped
	thumbnailer func(ctx context.Context, node models.Node, root string) error

	// thumbnailSupported answers whether a type can be rendered at this
	// moment, which is not fixed: video support appears when ffmpeg does
	thumbnailSupported func(mime string) bool

	// mediaProbe reads an image's dimensions and capture time. Wired in the
	// same way and for the same reason: this package does not import the one
	// that knows how to read a JPEG
	mediaProbe func(path string) (width, height int, takenAt int64, err error)
}

// Deps is what a Service needs to run.
type Deps struct {
	DB       *db.DB
	Store    *storage.Store
	Mirror   *storage.Mirror
	Libs     *libraries.Service
	Hub      *ws.Hub
	Audit    *audit.Logger
	Pool     *jobs.Pool
	Settings *settings.Service
	Log      *slog.Logger
}

// New returns a files Service.
func New(d Deps) *Service {
	log := d.Log
	if log == nil {
		log = slog.Default()
	}
	return &Service{
		database: d.DB, store: d.Store, mirror: d.Mirror, libs: d.Libs,
		hub: d.Hub, audit: d.Audit, pool: d.Pool, settings: d.Settings, log: log,
	}
}

// SetThumbnailer wires the preview generator in after construction, which
// keeps the thumbnails package from having to import this one.
func (s *Service) SetThumbnailer(fn func(ctx context.Context, node models.Node, root string) error) {
	s.thumbnailer = fn
}

// SetMediaProbe wires the image metadata reader in, for the same reason as
// SetThumbnailer.
func (s *Service) SetMediaProbe(fn func(path string) (width, height int, takenAt int64, err error)) {
	s.mediaProbe = fn
}

// OwnerRef is the small public shape of an account, enough for the shared-item
// badge and the People picker and nothing more.
type OwnerRef struct {
	ID         string
	Name       string
	AvatarSeed string
}

// View is a node plus everything the client needs to render it.
type View struct {
	Node           models.Node
	Owner          OwnerRef
	Role           models.AccessRole
	Starred        bool
	SharedWithMe   bool
	HasActiveShare bool
}

const viewColumns = `n.id, n.parent_id, n.owner_id, n.library_id, n.name, n.type, n.mime_type,
	n.size_bytes, n.checksum_sha256, n.color, n.has_thumbnail, n.thumbnail_generated_at,
	n.version_count, n.image_width, n.image_height, n.taken_at,
	n.created_at, n.updated_at, n.trashed_at, n.deleted_at`

const viewExtras = `u.id, u.username, u.display_name, u.avatar_seed,
	CASE WHEN st.node_id IS NULL THEN 0 ELSE 1 END,
	EXISTS(SELECT 1 FROM shares sh WHERE sh.node_id = n.id AND sh.revoked_at IS NULL
	        AND (sh.expires_at IS NULL OR sh.expires_at > ?))`

const viewJoins = `
	FROM nodes n
	JOIN users u ON u.id = n.owner_id
	LEFT JOIN stars st ON st.node_id = n.id AND st.user_id = ?`

// accessibleCTE seeds a recursive walk from every node explicitly shared with
// the caller, so a file deep inside a shared folder counts as accessible.
const accessibleCTE = `
WITH RECURSIVE shared_tree(id) AS (
	SELECT node_id FROM permissions WHERE user_id = ?
	UNION
	SELECT n.id FROM nodes n JOIN shared_tree s ON n.parent_id = s.id WHERE n.deleted_at IS NULL
)`

func (s *Service) scanViews(ctx context.Context, rows *sql.Rows, userID string) ([]View, error) {
	defer rows.Close()
	var out []View
	for rows.Next() {
		var (
			n                             models.Node
			parentID, checksum, color     sql.NullString
			hasThumb, starred, hasShare   int
			thumbAt, trashedAt, deletedAt sql.NullInt64
			takenAt                       sql.NullInt64
			nodeType                      string
			ownerID, username, display    string
			avatarSeed                    string
		)
		err := rows.Scan(&n.ID, &parentID, &n.OwnerID, &n.LibraryID, &n.Name, &nodeType, &n.MimeType,
			&n.SizeBytes, &checksum, &color, &hasThumb, &thumbAt, &n.VersionCount,
			&n.ImageWidth, &n.ImageHeight, &takenAt,
			&n.CreatedAt, &n.UpdatedAt, &trashedAt, &deletedAt,
			&ownerID, &username, &display, &avatarSeed, &starred, &hasShare)
		if err != nil {
			return nil, err
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

		name := display
		if name == "" {
			name = username
		}
		v := View{
			Node:           n,
			Owner:          OwnerRef{ID: ownerID, Name: name, AvatarSeed: avatarSeed},
			Starred:        starred != 0,
			HasActiveShare: hasShare != 0,
			SharedWithMe:   ownerID != userID,
		}
		out = append(out, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := s.fillRoles(ctx, userID, out); err != nil {
		return nil, err
	}
	return out, nil
}

// fillRoles resolves the caller's role for a page of results in one query
// rather than one lookup per row.
func (s *Service) fillRoles(ctx context.Context, userID string, views []View) error {
	if len(views) == 0 {
		return nil
	}
	roles := map[string]models.AccessRole{}
	needs := make([]any, 0, len(views)+1)
	needs = append(needs, userID)
	placeholders := make([]string, 0, len(views))
	for _, v := range views {
		if v.Node.OwnerID == userID {
			roles[v.Node.ID] = models.AccessOwner
			continue
		}
		placeholders = append(placeholders, "?")
		needs = append(needs, v.Node.ID)
	}
	if len(placeholders) > 0 {
		// an explicit row on the node itself, or the strongest one on any
		// ancestor, resolved for the whole page at once
		query := `
			WITH RECURSIVE up(target, id, parent_id, depth) AS (
				SELECT id, id, parent_id, 0 FROM nodes WHERE id IN (` + strings.Join(placeholders, ",") + `)
				UNION ALL
				SELECT u.target, n.id, n.parent_id, u.depth + 1
				  FROM nodes n JOIN up u ON n.id = u.parent_id WHERE u.depth < 128
			)
			SELECT up.target, MAX(CASE p.role WHEN 'editor' THEN 2 ELSE 1 END)
			  FROM up JOIN permissions p ON p.node_id = up.id
			 WHERE p.user_id = ?
			 GROUP BY up.target`
		args := append(needs[1:], userID)
		rows, err := s.database.Read().QueryContext(ctx, query, args...)
		if err != nil {
			return err
		}
		for rows.Next() {
			var id string
			var level int
			if err := rows.Scan(&id, &level); err != nil {
				rows.Close()
				return err
			}
			if level >= 2 {
				roles[id] = models.AccessEditor
			} else {
				roles[id] = models.AccessViewer
			}
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
	}
	for i := range views {
		views[i].Role = roles[views[i].Node.ID]
	}
	return nil
}

// ListOptions describes one folder listing or filtered view.
type ListOptions struct {
	ParentID string // "" or "root" for the blended top level
	Filter   string // "", "shared", "starred", "recent"
	Query    string
	Limit    int
	Offset   int
	SortBy   string // name | updated | size
	SortDesc bool
}

// List returns one page of a folder, or one of the filtered views.
func (s *Service) List(ctx context.Context, userID string, opts ListOptions) ([]View, error) {
	if opts.Limit <= 0 || opts.Limit > 500 {
		opts.Limit = 200
	}
	now := db.NowMillis()
	order := orderClause(opts.SortBy, opts.SortDesc)

	switch {
	case opts.Query != "":
		return s.search(ctx, userID, opts, now, order)
	case opts.Filter == "shared":
		rows, err := s.database.Read().QueryContext(ctx, `
			SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
			WHERE n.deleted_at IS NULL AND n.trashed_at IS NULL
			  AND n.owner_id != ?
			  AND n.id IN (SELECT node_id FROM permissions WHERE user_id = ?)
			`+order+` LIMIT ? OFFSET ?`,
			now, userID, userID, userID, opts.Limit, opts.Offset)
		if err != nil {
			return nil, err
		}
		return s.scanViews(ctx, rows, userID)

	case opts.Filter == "starred":
		rows, err := s.database.Read().QueryContext(ctx, accessibleCTE+`
			SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
			WHERE n.deleted_at IS NULL AND n.trashed_at IS NULL
			  AND st.node_id IS NOT NULL
			  AND (n.owner_id = ? OR n.id IN (SELECT id FROM shared_tree))
			`+order+` LIMIT ? OFFSET ?`,
			userID, now, userID, userID, opts.Limit, opts.Offset)
		if err != nil {
			return nil, err
		}
		return s.scanViews(ctx, rows, userID)

	// the gallery: every picture this account can reach, in one flat stream,
	// with no folders in it. Folders are how files are organised; a gallery is
	// how photos are looked at, and mixing the two would make it neither
	case opts.Filter == "gallery":
		rows, err := s.database.Read().QueryContext(ctx, accessibleCTE+`
			SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
			WHERE n.deleted_at IS NULL AND n.trashed_at IS NULL AND n.type = 'file'
			  AND (n.mime_type LIKE 'image/%' OR n.mime_type LIKE 'video/%')
			  AND (n.owner_id = ? OR n.id IN (SELECT id FROM shared_tree))
			`+order+` LIMIT ? OFFSET ?`,
			userID, now, userID, userID, opts.Limit, opts.Offset)
		if err != nil {
			return nil, err
		}
		return s.scanViews(ctx, rows, userID)

	case opts.Filter == "recent":
		rows, err := s.database.Read().QueryContext(ctx, accessibleCTE+`
			SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
			WHERE n.deleted_at IS NULL AND n.trashed_at IS NULL AND n.type = 'file'
			  AND (n.owner_id = ? OR n.id IN (SELECT id FROM shared_tree))
			ORDER BY n.updated_at DESC LIMIT ? OFFSET ?`,
			userID, now, userID, userID, opts.Limit, opts.Offset)
		if err != nil {
			return nil, err
		}
		return s.scanViews(ctx, rows, userID)
	}

	if opts.ParentID == "" || opts.ParentID == "root" {
		// the blended top level: this account's own items plus anything
		// shared directly with them
		rows, err := s.database.Read().QueryContext(ctx, `
			SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
			WHERE n.deleted_at IS NULL AND n.trashed_at IS NULL
			  AND ((n.parent_id IS NULL AND n.owner_id = ?)
			    OR n.id IN (SELECT node_id FROM permissions WHERE user_id = ?))
			`+order+` LIMIT ? OFFSET ?`,
			now, userID, userID, userID, opts.Limit, opts.Offset)
		if err != nil {
			return nil, err
		}
		return s.scanViews(ctx, rows, userID)
	}

	parent, err := s.Resolve(ctx, userID, opts.ParentID)
	if err != nil {
		return nil, err
	}
	if err := requireFolder(parent.Node); err != nil {
		return nil, err
	}
	if err := parent.Require(CapBrowse); err != nil {
		return nil, err
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
		WHERE n.parent_id = ? AND n.deleted_at IS NULL AND n.trashed_at IS NULL
		`+order+` LIMIT ? OFFSET ?`,
		now, userID, opts.ParentID, opts.Limit, opts.Offset)
	if err != nil {
		return nil, err
	}
	return s.scanViews(ctx, rows, userID)
}

func (s *Service) search(ctx context.Context, userID string, opts ListOptions, now int64, order string) ([]View, error) {
	pattern := "%" + strings.ReplaceAll(strings.ReplaceAll(opts.Query, "%", `\%`), "_", `\_`) + "%"
	rows, err := s.database.Read().QueryContext(ctx, accessibleCTE+`
		SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
		WHERE n.deleted_at IS NULL AND n.trashed_at IS NULL
		  AND n.name LIKE ? ESCAPE '\'
		  AND (n.owner_id = ? OR n.id IN (SELECT id FROM shared_tree))
		`+order+` LIMIT ? OFFSET ?`,
		userID, now, userID, pattern, userID, opts.Limit, opts.Offset)
	if err != nil {
		return nil, err
	}
	return s.scanViews(ctx, rows, userID)
}

func orderClause(sortBy string, desc bool) string {
	column := "n.name COLLATE NOCASE"
	switch sortBy {
	case "updated":
		column = "n.updated_at"
	case "size":
		column = "n.size_bytes"
	case "created":
		column = "n.created_at"
	case "taken":
		// when the picture was taken, falling back to when it was uploaded for
		// anything that carries no capture time. Without the fallback every
		// screenshot and download would pile up at one end of the gallery
		column = "COALESCE(n.taken_at, n.created_at)"
	}
	direction := "ASC"
	if desc {
		direction = "DESC"
	}
	// folders always sort above files, the way every file manager does
	return fmt.Sprintf("ORDER BY CASE n.type WHEN 'folder' THEN 0 ELSE 1 END, %s %s, n.id", column, direction)
}

// GetView returns one node with its badges resolved, for a detail screen.
func (s *Service) GetView(ctx context.Context, userID, nodeID string) (View, error) {
	acc, err := s.Resolve(ctx, userID, nodeID)
	if err != nil {
		return View{}, err
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
		WHERE n.id = ?`, db.NowMillis(), userID, nodeID)
	if err != nil {
		return View{}, err
	}
	views, err := s.scanViews(ctx, rows, userID)
	if err != nil {
		return View{}, err
	}
	if len(views) == 0 {
		return View{}, ErrNotFound
	}
	views[0].Role = acc.Role
	return views[0], nil
}

// ListTrash lists what the caller has thrown away. Only the top of each
// trashed subtree is listed; its contents went with it.
func (s *Service) ListTrash(ctx context.Context, userID string, limit, offset int) ([]View, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT `+viewColumns+`, `+viewExtras+viewJoins+`
		LEFT JOIN nodes parent ON parent.id = n.parent_id
		WHERE n.deleted_at IS NULL AND n.trashed_at IS NOT NULL AND n.owner_id = ?
		  AND (parent.id IS NULL OR parent.trashed_at IS NULL)
		ORDER BY n.trashed_at DESC LIMIT ? OFFSET ?`,
		db.NowMillis(), userID, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	return s.scanViews(ctx, rows, userID)
}

// Preview returns up to four thumbnailed children of a folder, for the
// content peek on its icon.
func (s *Service) Preview(ctx context.Context, userID, folderID string) ([]models.Node, error) {
	acc, err := s.Resolve(ctx, userID, folderID)
	if err != nil {
		return nil, err
	}
	if err := acc.Require(CapBrowse); err != nil {
		return nil, err
	}
	if err := requireFolder(acc.Node); err != nil {
		return nil, err
	}
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT `+nodeColumns+` FROM nodes
		WHERE parent_id = ? AND deleted_at IS NULL AND trashed_at IS NULL
		  AND type = 'file' AND has_thumbnail = 1
		ORDER BY updated_at DESC LIMIT 4`, folderID)
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

// OpenForDownload returns a readable handle on a file's bytes plus the node,
// after checking the caller may read it.
func (s *Service) OpenForDownload(ctx context.Context, userID, nodeID string) (models.Node, *os.File, os.FileInfo, error) {
	acc, err := s.Resolve(ctx, userID, nodeID)
	if err != nil {
		return models.Node{}, nil, nil, err
	}
	if err := acc.Require(CapBrowse); err != nil {
		return models.Node{}, nil, nil, err
	}
	f, info, err := s.OpenNodeBytes(acc.Node)
	return acc.Node, f, info, err
}

// OpenNodeBytes opens a node's object without an access check, for internal
// callers that have already resolved access, such as a public share.
func (s *Service) OpenNodeBytes(node models.Node) (*os.File, os.FileInfo, error) {
	if node.IsFolder() {
		return nil, nil, ErrNotAFile
	}
	root, err := s.libs.Root(node.LibraryID)
	if err != nil {
		return nil, nil, err
	}
	f, info, err := s.store.Open(root, node.ChecksumSHA256)
	if errors.Is(err, storage.ErrNotFound) {
		s.log.Error("object missing on disk", "node", node.ID, "checksum", node.ChecksumSHA256)
		return nil, nil, ErrNotFound
	}
	return f, info, err
}

// ThumbnailPath returns where a node's cached preview lives, if it has one.
func (s *Service) ThumbnailPath(ctx context.Context, userID, nodeID string) (models.Node, string, error) {
	acc, err := s.Resolve(ctx, userID, nodeID)
	if err != nil {
		return models.Node{}, "", err
	}
	if err := acc.Require(CapBrowse); err != nil {
		return models.Node{}, "", err
	}
	if !acc.Node.HasThumbnail {
		return acc.Node, "", ErrNotFound
	}
	root, err := s.libs.Root(acc.Node.LibraryID)
	if err != nil {
		return acc.Node, "", err
	}
	p, err := s.store.ThumbnailPath(root, acc.Node.ID)
	return acc.Node, p, err
}

// PublicChildren lists a folder's contents with no access check, for a public
// share whose scope the shares package has already verified.
func (s *Service) PublicChildren(ctx context.Context, parentID string) ([]models.Node, error) {
	rows, err := s.database.Read().QueryContext(ctx, `
		SELECT `+nodeColumns+` FROM nodes
		WHERE parent_id = ? AND deleted_at IS NULL AND trashed_at IS NULL
		ORDER BY CASE type WHEN 'folder' THEN 0 ELSE 1 END, name COLLATE NOCASE`, parentID)
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

// GetNode loads one node with no access check. Internal callers only.
func (s *Service) GetNode(ctx context.Context, id string) (models.Node, error) {
	return getNode(ctx, s.database.Read(), id)
}

// LibraryRoot exposes the library lookup to sibling packages such as shares.
func (s *Service) LibraryRoot(libraryID string) (string, error) {
	return s.libs.Root(libraryID)
}

// Store exposes the object store to sibling packages.
func (s *Service) Store() *storage.Store { return s.store }
