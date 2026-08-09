// Package sharepage renders the page somebody sees when they open a share
// link without having the app.
//
// A share link is the only part of Local Drive a stranger ever meets. Until
// now it answered JSON, so opening one in a browser showed a wall of braces:
// the file was there, the link worked, and it looked broken. This is the same
// data with a face on it.
//
// It is server rendered with htmx for the parts that change, rather than an
// application. A person following a link wants the file, not a bundle, and the
// server already knows everything the page needs.
package sharepage

import (
	"embed"
	"fmt"
	"html/template"
	"io"
	"net/http"
	"strings"
	"time"
)

//go:embed page.html listing.html htmx.min.js
var files embed.FS

// Assets is htmx, served from this binary rather than a cdn.
//
// A self hosted server that pulls a script from someone else's domain tells
// that someone the address of every person who opens a share link. The whole
// point of this project is that nobody is in the middle, and that has to hold
// for the one page strangers actually see.
var Assets, _ = files.ReadFile("htmx.min.js")

var templates = template.Must(template.New("").Funcs(helpers).ParseFS(files, "*.html"))

var helpers = template.FuncMap{
	"bytes":    HumanBytes,
	"when":     HumanTime,
	"icon":     glyphFor,
	"isFolder": func(kind string) bool { return kind == "folder" },
}

// Item is one row in a shared folder, or the shared file itself.
type Item struct {
	ID       string
	Name     string
	Kind     string // "folder" or "file"
	MimeType string
	Size     int64
	Modified int64
	// Thumb is true when the server can render a preview for this item.
	Thumb bool
}

// Data is everything the page needs. The handler fills it; the template makes
// no decisions of its own beyond which branch to draw.
type Data struct {
	// ServerName is what the operator called their server.
	ServerName string
	Token      string

	// Item is what the link points at.
	Item Item
	// Owner is who shared it, by display name. Never an email or an account id.
	Owner string

	AllowDownload bool
	ExpiresAt     int64

	// NeedsPassword puts the page into its locked state. Wrong is set when a
	// password was tried and rejected, so the form can say so.
	NeedsPassword bool
	Wrong         bool

	// Gone covers a link that expired or never existed. Deliberately one state
	// with one message: telling a stranger which of the two it is confirms
	// that a token existed, which is information they did not have.
	Gone bool

	// Children and Trail are the folder view. Empty for a single file.
	Children []Item
	Trail    []Crumb

	// Password is echoed back into links and forms so that navigating inside a
	// protected folder does not ask for it again on every click.
	Password string

	// BrandURL is where "what is this" goes.
	BrandURL string
}

// Crumb is one step in the path inside a shared folder.
type Crumb struct {
	ID   string
	Name string
}

// Render writes the whole page.
func Render(w http.ResponseWriter, status int, data Data) {
	write(w, status, "page.html", data)
}

// RenderListing writes only the folder contents, which is what htmx swaps in
// when somebody opens a folder inside a share.
func RenderListing(w http.ResponseWriter, data Data) {
	write(w, http.StatusOK, "listing.html", data)
}

func write(w http.ResponseWriter, status int, name string, data Data) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	// the page is built from one person's private file names, so it must not
	// be held in a shared cache anywhere between here and the reader
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.WriteHeader(status)
	if err := templates.ExecuteTemplate(w, name, data); err != nil {
		// the status is already written, so there is nowhere to report this
		// except the log the caller owns
		_, _ = io.WriteString(w, "")
	}
}

// WantsHTML reports whether this request came from a browser rather than from
// the app.
//
// The app asks for JSON explicitly. A browser sends an Accept header that
// prefers html. Anything else, including curl with no Accept at all, keeps the
// JSON it has always had, so nothing that already works changes.
func WantsHTML(r *http.Request) bool {
	if r.Header.Get("HX-Request") != "" {
		return true
	}
	accept := r.Header.Get("Accept")
	if !strings.Contains(accept, "text/html") {
		return false
	}
	// an Accept listing both wins for whichever is asked for first
	return strings.Index(accept, "text/html") < indexOrMax(accept, "application/json")
}

func indexOrMax(haystack, needle string) int {
	if at := strings.Index(haystack, needle); at >= 0 {
		return at
	}
	return len(haystack) + 1
}

// HumanBytes is a size a person reads, not a number of bytes.
func HumanBytes(n int64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := int64(unit), 0
	for size := n / unit; size >= unit && exp < 3; size /= unit {
		div *= unit
		exp++
	}
	value := float64(n) / float64(div)
	suffix := [...]string{"KB", "MB", "GB", "TB"}[exp]
	if value >= 10 {
		return fmt.Sprintf("%.0f %s", value, suffix)
	}
	return fmt.Sprintf("%.1f %s", value, suffix)
}

// HumanTime is a date, or empty for a zero timestamp.
func HumanTime(unix int64) string {
	if unix <= 0 {
		return ""
	}
	return time.Unix(unix, 0).UTC().Format("2 January 2006")
}

// glyphFor picks the outline drawn on a tile. Deliberately a small set: the
// app has file type colours that mean something, and inventing a second
// vocabulary here would make the two disagree.
func glyphFor(item Item) string {
	if item.Kind == "folder" {
		return "folder"
	}
	mime := strings.ToLower(item.MimeType)
	switch {
	case strings.HasPrefix(mime, "image/"):
		return "image"
	case strings.HasPrefix(mime, "video/"):
		return "video"
	case strings.HasPrefix(mime, "audio/"):
		return "audio"
	case strings.Contains(mime, "pdf"):
		return "pdf"
	case strings.HasPrefix(mime, "text/"), strings.Contains(mime, "json"),
		strings.Contains(mime, "xml"):
		return "text"
	case strings.Contains(mime, "zip"), strings.Contains(mime, "tar"),
		strings.Contains(mime, "compress"):
		return "archive"
	}
	return "file"
}
