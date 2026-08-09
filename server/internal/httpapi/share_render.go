package httpapi

import (
	"bytes"
	"errors"
	"net/http"
	"net/url"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/httpapi/sharepage"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/shares"
)

// brandURL is where "get the app" goes. Not configurable: pointing it
// elsewhere would send visitors to something this project did not publish.
const brandURL = "https://localdrive.iprog.dev"

// handleShareAsset serves htmx. Immutable per build, so it caches hard.
func (a *API) handleShareAsset(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/javascript; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	http.ServeContent(w, r, "htmx.js", buildTime, bytes.NewReader(sharepage.Assets))
}

// buildTime is fixed so conditional requests work without pretending the
// file changes.
var buildTime = time.Unix(0, 0)

func (a *API) renderSharePage(
	w http.ResponseWriter,
	r *http.Request,
	resolved shares.Resolved,
	password string,
) {
	owner, _ := a.shares.OwnerOf(r.Context(), resolved.Node)
	a.shares.RecordAccess(r.Context(), resolved.Share, clientIP(r), "view")

	data := sharepage.Data{
		ServerName:    a.serverName(),
		Token:         resolved.Share.Token,
		Item:          shareItem(resolved.Node),
		Owner:         owner,
		AllowDownload: resolved.Share.AllowDownload,
		ExpiresAt:     resolved.Share.ExpiresAt,
		Password:      password,
		BrandURL:      brandURL,
	}

	// The player reads from the download endpoint, so a view only link has
	// nothing to stream. That link exists to withhold the file.
	if resolved.Share.AllowDownload {
		if kind := sharepage.PreviewKind(resolved.Node.MimeType); kind != "" {
			data.Preview = kind
			data.MediaURL = "/s/" + resolved.Share.Token + "/download"
			if password != "" {
				data.MediaURL += "?password=" + url.QueryEscape(password)
			}
		}
	}

	// a shared folder shows its contents straight away
	if resolved.Node.Type == models.NodeFolder {
		if children, err := a.files.PublicChildren(r.Context(), resolved.Node.ID); err == nil {
			data.Children = shareItems(children)
		}
		data.Trail = []sharepage.Crumb{{ID: resolved.Node.ID, Name: resolved.Node.Name}}
	}

	sharepage.Render(w, http.StatusOK, data)
}

func (a *API) renderShareListing(
	w http.ResponseWriter,
	r *http.Request,
	resolved shares.Resolved,
	parentID string,
	children []models.Node,
	password string,
) {
	data := sharepage.Data{
		ServerName:    a.serverName(),
		Token:         resolved.Share.Token,
		Item:          shareItem(resolved.Node),
		AllowDownload: resolved.Share.AllowDownload,
		Children:      shareItems(children),
		Password:      password,
		BrandURL:      brandURL,
		Trail:         a.shareTrail(r, resolved, parentID),
	}
	sharepage.RenderListing(w, data)
}

// renderShareError turns a refusal into a page rather than an envelope.
//
// A password prompt gets the form. Everything else gets one "not available"
// page, because saying which failure it was confirms a token existed.
func (a *API) renderShareError(
	w http.ResponseWriter,
	r *http.Request,
	token, password string,
	err error,
) {
	data := sharepage.Data{
		ServerName: a.serverName(),
		Token:      token,
		BrandURL:   brandURL,
	}

	switch {
	case errors.Is(err, shares.ErrPasswordNeeded):
		data.NeedsPassword = true
		sharepage.Render(w, http.StatusUnauthorized, data)
	case errors.Is(err, shares.ErrPasswordWrong):
		data.NeedsPassword = true
		data.Wrong = password != ""
		sharepage.Render(w, http.StatusUnauthorized, data)
	default:
		data.Gone = true
		sharepage.Render(w, http.StatusNotFound, data)
	}
	_ = r
}

// shareTrail walks up to the shared root, and stops there: names above the
// share were never shared.
func (a *API) shareTrail(
	r *http.Request,
	resolved shares.Resolved,
	parentID string,
) []sharepage.Crumb {
	root := resolved.Node
	trail := []sharepage.Crumb{{ID: root.ID, Name: root.Name}}
	if parentID == "" || parentID == root.ID {
		return trail
	}

	// bounded, so a cycle in the data cannot spin here
	var up []sharepage.Crumb
	current := parentID
	for i := 0; i < 32 && current != "" && current != root.ID; i++ {
		node, err := a.shares.PublicChild(r.Context(), resolved.Share, current)
		if err != nil {
			break
		}
		up = append(up, sharepage.Crumb{ID: node.ID, Name: node.Name})
		current = node.ParentID
	}
	for i := len(up) - 1; i >= 0; i-- {
		trail = append(trail, up[i])
	}
	return trail
}

func (a *API) serverName() string {
	if name := a.settings.Get().ServerName; name != "" {
		return name
	}
	return "Local Drive"
}

func shareItem(node models.Node) sharepage.Item {
	kind := "file"
	if node.Type == models.NodeFolder {
		kind = "folder"
	}
	return sharepage.Item{
		ID:       node.ID,
		Name:     node.Name,
		Kind:     kind,
		MimeType: node.MimeType,
		Size:     node.SizeBytes,
		Modified: node.UpdatedAt,
		Thumb:    node.HasThumbnail,
	}
}

func shareItems(nodes []models.Node) []sharepage.Item {
	out := make([]sharepage.Item, 0, len(nodes))
	for _, node := range nodes {
		out = append(out, shareItem(node))
	}
	return out
}
