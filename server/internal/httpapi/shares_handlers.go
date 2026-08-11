package httpapi

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/MultiX0/LocalDrive/server/internal/httpapi/sharepage"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/shares"
)

type shareDTO struct {
	ID                string `json:"id"`
	NodeID            string `json:"node_id"`
	Token             string `json:"token"`
	URL               string `json:"url"`
	ExpiresAt         int64  `json:"expires_at,omitempty"`
	AllowDownload     bool   `json:"allow_download"`
	PasswordProtected bool   `json:"password_protected"`
	CreatedAt         int64  `json:"created_at"`
	RevokedAt         int64  `json:"revoked_at,omitempty"`
	Active            bool   `json:"active"`
}

func (a *API) shareBody(s models.Share) shareDTO {
	return shareDTO{
		ID: s.ID, NodeID: s.NodeID, Token: s.Token, URL: a.shares.URL(s),
		ExpiresAt: s.ExpiresAt, AllowDownload: s.AllowDownload,
		PasswordProtected: s.PasswordHash != "", CreatedAt: s.CreatedAt,
		RevokedAt: s.RevokedAt, Active: s.Active(nowMillis()),
	}
}

type createShareRequest struct {
	Password      string `json:"password"`
	ExpiresAt     int64  `json:"expires_at"`
	AllowDownload *bool  `json:"allow_download"`
}

func (a *API) handleCreateShare(w http.ResponseWriter, r *http.Request) {
	var req createShareRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	if replayed, ok := a.replayIdempotent(w, r, "nodes.share"); ok {
		_ = replayed
		return
	}
	userID, ip := caller(r)
	allowDownload := true
	if req.AllowDownload != nil {
		allowDownload = *req.AllowDownload
	}
	share, err := a.shares.Create(r.Context(), shares.CreateParams{
		UserID: userID, NodeID: chi.URLParam(r, "id"), Password: req.Password,
		ExpiresAt: req.ExpiresAt, AllowDownload: allowDownload, IP: ip,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	body := a.shareBody(share)
	a.storeIdempotent(r, "nodes.share", body)
	writeJSON(w, http.StatusCreated, body)
}

type updateShareRequest struct {
	Password      *string `json:"password"`
	ExpiresAt     *int64  `json:"expires_at"`
	AllowDownload *bool   `json:"allow_download"`
}

func (a *API) handleUpdateShare(w http.ResponseWriter, r *http.Request) {
	var req updateShareRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	userID, ip := caller(r)
	share, err := a.shares.Update(r.Context(), shares.UpdateParams{
		UserID: userID, ShareID: chi.URLParam(r, "id"),
		Password: req.Password, ExpiresAt: req.ExpiresAt,
		AllowDownload: req.AllowDownload, IP: ip,
	})
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, a.shareBody(share))
}

func (a *API) handleRevokeShare(w http.ResponseWriter, r *http.Request) {
	userID, ip := caller(r)
	if err := a.shares.Revoke(r.Context(), userID, chi.URLParam(r, "id"), ip); err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) handleListNodeShares(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	list, err := a.shares.ListForNode(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]shareDTO, 0, len(list))
	for _, s := range list {
		out = append(out, a.shareBody(s))
	}
	writeJSON(w, http.StatusOK, map[string]any{"shares": out})
}

func (a *API) handleListMyShares(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	list, err := a.shares.ListByUser(r.Context(), userID)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]shareDTO, 0, len(list))
	for _, s := range list {
		out = append(out, a.shareBody(s))
	}
	writeJSON(w, http.StatusOK, map[string]any{"shares": out})
}

type grantRequest struct {
	UserID string `json:"user_id"`
	Role   string `json:"role"`
}

func (a *API) handleGrantAccess(w http.ResponseWriter, r *http.Request) {
	var req grantRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	ownerID, ip := caller(r)
	grant, err := a.shares.GrantAccess(r.Context(), ownerID, chi.URLParam(r, "id"),
		req.UserID, strings.ToLower(strings.TrimSpace(req.Role)), ip)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, grantBody(grant))
}

func (a *API) handleRevokeAccess(w http.ResponseWriter, r *http.Request) {
	ownerID, ip := caller(r)
	err := a.shares.RevokeAccess(r.Context(), ownerID, chi.URLParam(r, "id"),
		chi.URLParam(r, "userID"), ip)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) handleListGrants(w http.ResponseWriter, r *http.Request) {
	userID, _ := caller(r)
	list, err := a.shares.ListGrants(r.Context(), userID, chi.URLParam(r, "id"))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	out := make([]map[string]any, 0, len(list))
	for _, g := range list {
		out = append(out, grantBody(g))
	}
	writeJSON(w, http.StatusOK, map[string]any{"people": out})
}

func grantBody(g shares.Grant) map[string]any {
	return map[string]any{
		"user_id":     g.UserID,
		"name":        g.Name,
		"avatar_seed": g.AvatarSeed,
		"role":        g.Role,
		"created_at":  g.CreatedAt,
	}
}

// public share endpoints, unauthenticated

type sharePasswordRequest struct {
	Password string `json:"password"`
}

// sharePassword finds the password wherever the caller put it.
//
// Two clients post to this route and they disagree, so both have to be read.
// The share page is a plain html form, which a browser sends form encoded; the
// apps send json. Reading only json meant a password typed into the page came
// back empty, the share refused to open, and the page re-rendered with the same
// prompt. A correct password looked wrong, with nothing to say why.
func sharePassword(r *http.Request) string {
	if pw := strings.TrimSpace(r.URL.Query().Get("password")); pw != "" {
		return pw
	}
	if pw := strings.TrimSpace(r.Header.Get("X-Share-Password")); pw != "" {
		return pw
	}
	if r.Method != http.MethodPost || r.Body == nil {
		return ""
	}

	// read once and try both, rather than trusting a Content-Type that a
	// hand-written client may not have set
	body, err := io.ReadAll(io.LimitReader(r.Body, maxJSONBody))
	r.Body.Close()
	if err != nil {
		return ""
	}
	// put it back, so anything further down the chain can still read it
	r.Body = io.NopCloser(bytes.NewReader(body))

	var parsed sharePasswordRequest
	if json.Unmarshal(body, &parsed) == nil {
		if pw := strings.TrimSpace(parsed.Password); pw != "" {
			return pw
		}
	}
	if values, err := url.ParseQuery(string(body)); err == nil {
		if pw := strings.TrimSpace(values.Get("password")); pw != "" {
			return pw
		}
	}
	return ""
}

func (a *API) handleShareInfo(w http.ResponseWriter, r *http.Request) {
	token := chi.URLParam(r, "token")
	password := sharePassword(r)
	resolved, err := a.shares.ResolvePublic(r.Context(), token, password)
	if err != nil {
		// A browser gets a page explaining what happened. The app gets the
		// error envelope it has always parsed.
		if sharepage.WantsHTML(r) {
			a.renderShareError(w, r, token, password, err)
			return
		}
		a.fail(w, r, err)
		return
	}

	if sharepage.WantsHTML(r) {
		a.renderSharePage(w, r, resolved, password)
		return
	}
	ownerName, _ := a.shares.OwnerOf(r.Context(), resolved.Node)
	a.shares.RecordAccess(r.Context(), resolved.Share, clientIP(r), "view")

	node := plainNode(resolved.Node)
	node.Checksum = ""
	writeJSON(w, http.StatusOK, map[string]any{
		"node":           node,
		"owner_name":     ownerName,
		"allow_download": resolved.Share.AllowDownload,
		"expires_at":     resolved.Share.ExpiresAt,
	})
}

func (a *API) handleShareChildren(w http.ResponseWriter, r *http.Request) {
	resolved, err := a.shares.ResolvePublic(r.Context(), chi.URLParam(r, "token"), sharePassword(r))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	parentID := strings.TrimSpace(r.URL.Query().Get("parent_id"))
	if parentID == "" {
		parentID = resolved.Share.NodeID
	}
	if _, err := a.shares.PublicChild(r.Context(), resolved.Share, parentID); err != nil {
		a.fail(w, r, err)
		return
	}
	children, err := a.files.PublicChildren(r.Context(), parentID)
	if err != nil {
		a.fail(w, r, err)
		return
	}

	// htmx asks for this same url and swaps the folder box in place, so the
	// answer is the listing on its own rather than a whole page
	if sharepage.WantsHTML(r) {
		a.renderShareListing(w, r, resolved, parentID, children, sharePassword(r))
		return
	}

	out := make([]nodeDTO, 0, len(children))
	for _, n := range children {
		dto := plainNode(n)
		dto.Checksum = ""
		out = append(out, dto)
	}
	writeJSON(w, http.StatusOK, map[string]any{"nodes": out})
}

func (a *API) handleShareDownload(w http.ResponseWriter, r *http.Request) {
	resolved, err := a.shares.ResolvePublic(r.Context(), chi.URLParam(r, "token"), sharePassword(r))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	if !resolved.Share.AllowDownload {
		a.fail(w, r, shares.ErrDownloadBlocked)
		return
	}
	node := resolved.Node
	if requested := strings.TrimSpace(r.URL.Query().Get("node_id")); requested != "" {
		node, err = a.shares.PublicChild(r.Context(), resolved.Share, requested)
		if err != nil {
			a.fail(w, r, err)
			return
		}
	}
	f, info, err := a.files.OpenNodeBytes(node)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	defer f.Close()
	a.shares.RecordAccess(r.Context(), resolved.Share, clientIP(r), "download")
	serveNode(w, r, node, f, info, boolQuery(r, "inline"))
}

func (a *API) handleShareThumbnail(w http.ResponseWriter, r *http.Request) {
	resolved, err := a.shares.ResolvePublic(r.Context(), chi.URLParam(r, "token"), sharePassword(r))
	if err != nil {
		a.fail(w, r, err)
		return
	}
	node := resolved.Node
	if requested := strings.TrimSpace(r.URL.Query().Get("node_id")); requested != "" {
		node, err = a.shares.PublicChild(r.Context(), resolved.Share, requested)
		if err != nil {
			a.fail(w, r, err)
			return
		}
	}
	if !node.HasThumbnail {
		writeError(w, http.StatusNotFound, "no_thumbnail", "this file has no preview")
		return
	}
	root, err := a.files.LibraryRoot(node.LibraryID)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	path, err := a.files.Store().ThumbnailPath(root, node.ID)
	if err != nil {
		a.fail(w, r, err)
		return
	}
	serveThumbnail(w, r, node, path)
}
