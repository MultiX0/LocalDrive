package httpapi

import (
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/files"
	mw "github.com/MultiX0/LocalDrive/server/internal/middleware"
	"github.com/MultiX0/LocalDrive/server/internal/models"
)

func (a *API) handleListNodes(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	opts := files.ListOptions{
		ParentID: strings.TrimSpace(r.URL.Query().Get("parent_id")),
		Filter:   strings.TrimSpace(r.URL.Query().Get("filter")),
		Query:    strings.TrimSpace(r.URL.Query().Get("query")),
		Limit:    intQuery(r, "limit", 200),
		Offset:   intQuery(r, "offset", 0),
		SortBy:   strings.TrimSpace(r.URL.Query().Get("sort")),
		SortDesc: strings.EqualFold(r.URL.Query().Get("order"), "desc"),
	}
	list, err := a.files.List(r.Context(), userID, opts)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"nodes":  nodeViews(list, userID),
		"limit":  opts.Limit,
		"offset": opts.Offset,
	})
}

type createFolderRequest struct {
	ParentID  string `json:"parent_id"`
	Name      string `json:"name"`
	LibraryID string `json:"library_id"`
	Color     string `json:"color"`
}

func (a *API) handleCreateFolder(w http.ResponseWriter, r *http.Request) {
	var req createFolderRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID, ip := caller(r)

	if replayed, ok := a.replayIdempotent(w, r, "nodes.folder"); ok {
		_ = replayed
		return
	}
	node, err := a.files.CreateFolder(r.Context(), files.CreateFolderParams{
		UserID: userID, ParentID: req.ParentID, Name: req.Name,
		LibraryID: req.LibraryID, Color: req.Color, IP: ip,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	body := plainNode(node)
	a.storeIdempotent(r, "nodes.folder", body)
	writeJSON(w, http.StatusCreated, body)
}

func (a *API) handleGetNode(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	view, err := a.files.GetView(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, nodeView(view, userID))
}

func (a *API) handleNodePath(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	chain, err := a.files.PathTo(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]nodeDTO, 0, len(chain))
	for _, n := range chain {
		out = append(out, plainNode(n))
	}
	writeJSON(w, http.StatusOK, map[string]any{"path": out})
}

type patchNodeRequest struct {
	Name     *string `json:"name"`
	ParentID *string `json:"parent_id"`
	Color    *string `json:"color"`
}

// handlePatchNode covers rename, move, and recolor, each with its own
// capability check inside the files service.
func (a *API) handlePatchNode(w http.ResponseWriter, r *http.Request) {
	var req patchNodeRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID, ip := caller(r)
	nodeID := chi.URLParam(r, "id")

	var (
		node models.Node
		err  error
		did  bool
	)
	if req.Name != nil {
		node, err = a.files.Rename(r.Context(), files.RenameParams{
			UserID: userID, NodeID: nodeID, Name: *req.Name, IP: ip,
		})
		if err != nil {
			a.fail(w, r, err)
			return
		}
		did = true
	}
	if req.ParentID != nil {
		node, err = a.files.Move(r.Context(), files.MoveParams{
			UserID: userID, NodeID: nodeID, ParentID: *req.ParentID, IP: ip,
		})
		if err != nil {
			a.fail(w, r, err)
			return
		}
		did = true
	}
	if req.Color != nil {
		node, err = a.files.Recolor(r.Context(), userID, nodeID, *req.Color, ip)
		if err != nil {
			a.fail(w, r, err)
			return
		}
		did = true
	}
	if !did {
		writeError(w, http.StatusBadRequest, "invalid_request", "nothing to change")
		return
	}
	writeJSON(w, http.StatusOK, plainNode(node))
}

func (a *API) handleTrashNode(w http.ResponseWriter, r *http.Request) {
	userID, ip := caller(r)
	node, err := a.files.Trash(r.Context(), userID, chi.URLParam(r, "id"), ip)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, plainNode(node))
}

func (a *API) handleRestoreNode(w http.ResponseWriter, r *http.Request) {
	userID, ip := caller(r)
	node, err := a.files.Restore(r.Context(), userID, chi.URLParam(r, "id"), ip)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, plainNode(node))
}

func (a *API) handleDeleteNode(w http.ResponseWriter, r *http.Request) {
	userID, ip := caller(r)
	if err := a.files.PermanentDelete(r.Context(), userID, chi.URLParam(r, "id"), ip); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) handleStar(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	if err := a.files.Star(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) handleUnstar(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	if err := a.files.Unstar(r.Context(), userID, chi.URLParam(r, "id")); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// handleFolderPreview returns up to four thumbnail urls for the content peek
// on a folder's icon.
func (a *API) handleFolderPreview(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	children, err := a.files.Preview(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]map[string]any, 0, len(children))
	for _, n := range children {
		out = append(out, map[string]any{
			"node_id":       n.ID,
			"thumbnail_url": fmt.Sprintf("/api/v1/nodes/%s/thumbnail", n.ID),
			"category":      string(models.CategoryOf(n.Type, n.MimeType, n.Name)),
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"previews": out})
}

// handleDownload streams a file, honoring Range so video scrubbing and
// resumed downloads work without reading anything into memory.
func (a *API) handleDownload(w http.ResponseWriter, r *http.Request) {
	userID, ip := caller(r)
	node, f, info, err := a.files.OpenForDownload(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	defer f.Close()

	a.audit.Record(r.Context(), audit.Entry{
		UserID: userID, NodeID: node.ID, Action: audit.ActionNodeDownloaded, IP: ip,
		Metadata: map[string]any{"name": node.Name},
	})
	serveNode(w, r, node, f, info, boolQuery(r, "inline"))
}

// serveNode is the one place a file's bytes reach the network, shared by the
// authenticated download and the public share download.
func serveNode(w http.ResponseWriter, r *http.Request, node models.Node, f *os.File, info os.FileInfo, inline bool) {
	contentType := node.MimeType
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	disposition := "attachment"
	if inline && models.Previewable(models.CategoryOf(node.Type, node.MimeType, node.Name)) {
		disposition = "inline"
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Disposition", fmt.Sprintf(`%s; filename="%s"; filename*=UTF-8''%s`,
		disposition, sanitizeFilename(node.Name), url.PathEscape(node.Name)))
	w.Header().Set("Accept-Ranges", "bytes")

	// the path is the content hash, so the bytes behind this url can never
	// change; that makes an immutable cache entry correct rather than risky
	if node.ChecksumSHA256 != "" {
		w.Header().Set("ETag", `"`+node.ChecksumSHA256+`"`)
		w.Header().Set("Cache-Control", "private, max-age=31536000, immutable")
	}
	modTime := info.ModTime()
	if node.UpdatedAt > 0 {
		modTime = time.UnixMilli(node.UpdatedAt)
	}
	http.ServeContent(w, r, node.Name, modTime, f)
}

func sanitizeFilename(name string) string {
	replacer := strings.NewReplacer(`"`, "", "\\", "", "\r", "", "\n", "")
	return replacer.Replace(name)
}

func (a *API) handleThumbnail(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	node, path, err := a.files.ThumbnailPath(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		// a missing preview is normal: the client falls back to a type badge
		writeError(w, http.StatusNotFound, "no_thumbnail", "this file has no preview")
		return
	}
	serveThumbnail(w, r, node, path)
}

func serveThumbnail(w http.ResponseWriter, r *http.Request, node models.Node, path string) {
	f, err := os.Open(path)
	if err != nil {
		writeError(w, http.StatusNotFound, "no_thumbnail", "this file has no preview")
		return
	}
	defer f.Close()
	info, err := f.Stat()
	if err != nil {
		writeError(w, http.StatusNotFound, "no_thumbnail", "this file has no preview")
		return
	}
	w.Header().Set("Content-Type", "image/jpeg")
	if node.ChecksumSHA256 != "" {
		w.Header().Set("ETag", `"thumb-`+node.ChecksumSHA256+`"`)
		w.Header().Set("Cache-Control", "private, max-age=31536000, immutable")
	}
	http.ServeContent(w, r, "thumbnail.jpg", info.ModTime(), f)
}

func (a *API) handleListVersions(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	versions, err := a.files.Versions(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]map[string]any, 0, len(versions))
	for _, v := range versions {
		out = append(out, map[string]any{
			"id":         v.ID,
			"size_bytes": v.SizeBytes,
			"mime_type":  v.MimeType,
			"created_by": v.CreatedBy,
			"created_at": v.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"versions": out})
}

func (a *API) handleRestoreVersion(w http.ResponseWriter, r *http.Request) {
	userID, ip := caller(r)
	node, err := a.files.RestoreVersion(r.Context(), userID,
		chi.URLParam(r, "id"), chi.URLParam(r, "vid"), ip)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, plainNode(node))
}

func (a *API) handleListTrash(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	list, err := a.files.ListTrash(r.Context(), userID, intQuery(r, "limit", 200), intQuery(r, "offset", 0))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	cfg := a.settings.Get()
	writeJSON(w, http.StatusOK, map[string]any{
		"nodes":          nodeViews(list, userID),
		"retention_days": cfg.TrashRetentionDays,
	})
}

func (a *API) handleActivity(w http.ResponseWriter, r *http.Request) {
	user, _ := mw.UserFrom(r.Context())
	adminAll := user.IsAdmin() && boolQuery(r, "all")
	list, err := a.audit.List(r.Context(), audit.ListOptions{
		UserID:   user.ID,
		NodeID:   strings.TrimSpace(r.URL.Query().Get("node_id")),
		Action:   strings.TrimSpace(r.URL.Query().Get("action")),
		Limit:    intQuery(r, "limit", 50),
		Before:   int64Query(r, "before", 0),
		AdminAll: adminAll,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]map[string]any, 0, len(list))
	for _, entry := range list {
		out = append(out, map[string]any{
			"id":         entry.ID,
			"user_id":    entry.UserID,
			"node_id":    entry.NodeID,
			"action":     entry.Action,
			"metadata":   entry.Metadata,
			"created_at": entry.CreatedAt,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"activity": out})
}
