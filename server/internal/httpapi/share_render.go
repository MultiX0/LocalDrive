package httpapi

import (
	"bytes"
	"errors"
	"net/http"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/httpapi/sharepage"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/shares"
)

// The page a stranger sees when they open a share link in a browser.
//
// Everything here is the same data the app receives, arranged for somebody who
// has never heard of this project and is one click from deciding it is broken.

// brandURL is where "get the app" goes. Not configurable: it is the project's
// own site, and an operator pointing it at their own page would be telling
// their visitors to install something the project did not publish.
const brandURL = "https://localdrive.iprog.dev"

// handleShareAsset serves the one script the share page uses. It is immutable
// for a given build, so it can be cached hard.
func (a *API) handleShareAsset(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/javascript; charset=utf-8")
	w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	http.ServeContent(w, r, "htmx.js", buildTime, bytes.NewReader(sharepage.Assets))
}

// buildTime is fixed so ServeContent can answer a conditional request without
// pretending the file changes.
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

	// a shared folder shows what is in it straight away, rather than an empty
	// card that needs a click before it says anything
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

// renderShareError turns a refusal into a page rather than an error envelope.
//
// A password prompt is not a failure, so it gets the form. Everything else
// becomes one "not available" page: telling a stranger whether a token existed
// but expired, or never existed at all, answers a question they should not be
// able to ask.
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

// shareTrail walks back up to the shared root so the path inside a shared
// folder can be clicked. It stops at the share itself, because anything above
// that was never shared and its names must not appear.
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

	// walk up from where we are, then reverse, bounded so a cycle in the data
	// cannot spin here
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
