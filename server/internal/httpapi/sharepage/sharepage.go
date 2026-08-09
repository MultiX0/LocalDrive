// Package sharepage renders what a browser gets when it opens a share link.
//
// The same data the app receives as JSON, as a page. Server rendered, with
// htmx for the parts that change.
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

// Assets is htmx, vendored rather than loaded from a cdn: a cdn would learn
// the address of everyone who opens a share link.
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

// Data is everything the page needs.
type Data struct {
	// ServerName is what the operator called their server.
	ServerName string
	Token      string

	// Item is what the link points at.
	Item Item
	// Owner is a display name. Never an email or an account id.
	Owner string

	AllowDownload bool
	ExpiresAt     int64

	// NeedsPassword puts the page into its locked state. Wrong is set when a
	// password was tried and rejected, so the form can say so.
	NeedsPassword bool
	Wrong         bool

	// Gone covers expired and never existed alike. Saying which confirms a
	// token existed.
	Gone bool

	// Children and Trail are the folder view. Empty for a single file.
	Children []Item
	Trail    []Crumb

	// Password is echoed into links so navigating a protected folder does not
	// ask again on every click.
	Password string

	// Preview is "image", "video", "audio" or empty. Only those three, because
	// they are what a browser plays without help.
	Preview string
	// MediaURL is what the preview element loads, already carrying the
	// password when the link has one.
	MediaURL string

	// BrandURL is where "what is this" goes.
	BrandURL string
}

// PreviewKind reports how a browser can show this file in place, or "".
//
// Only the three it handles natively. A viewer that renders nothing is worse
// than a download button.
func PreviewKind(mimeType string) string {
	mime := strings.ToLower(strings.TrimSpace(mimeType))
	switch {
	case strings.HasPrefix(mime, "image/"):
		// svg is markup that the browser will execute, from a file somebody
		// else uploaded, on this server's origin
		if strings.Contains(mime, "svg") {
			return ""
		}
		return "image"
	case strings.HasPrefix(mime, "video/"):
		return "video"
	case strings.HasPrefix(mime, "audio/"):
		return "audio"
	}
	return ""
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

// WantsHTML reports whether a browser is asking, rather than the app.
//
// Anything that does not prefer html keeps the JSON it has always had.
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

// glyphFor picks the outline drawn on a tile. A small set on purpose: the app
// already has file type colours, and a second vocabulary would disagree.
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
