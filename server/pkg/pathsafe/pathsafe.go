// Package pathsafe canonicalizes filesystem paths and guarantees a resolved
// path stays inside a given root. Used as the second line of defense behind
// API-layer validation.
package pathsafe

import (
	"errors"
	"path/filepath"
	"strings"
	"unicode"
)

var (
	// ErrEscapesRoot is returned when a joined path resolves outside its root.
	ErrEscapesRoot = errors.New("pathsafe: path escapes its library root")
	// ErrInvalidSegment is returned for a name that can never be a safe segment.
	ErrInvalidSegment = errors.New("pathsafe: invalid path segment")
	// ErrEmptyName is returned for an empty or whitespace-only name.
	ErrEmptyName = errors.New("pathsafe: empty name")
	// ErrNameTooLong is returned for a name longer than MaxNameLength bytes.
	ErrNameTooLong = errors.New("pathsafe: name too long")
)

// MaxNameLength is the longest single node name accepted, in bytes.
const MaxNameLength = 255

// reserved windows device names, rejected so a library stays portable
var reservedNames = map[string]struct{}{
	"con": {}, "prn": {}, "aux": {}, "nul": {},
	"com1": {}, "com2": {}, "com3": {}, "com4": {}, "com5": {},
	"com6": {}, "com7": {}, "com8": {}, "com9": {},
	"lpt1": {}, "lpt2": {}, "lpt3": {}, "lpt4": {}, "lpt5": {},
	"lpt6": {}, "lpt7": {}, "lpt8": {}, "lpt9": {},
}

// ValidateName checks a single user-supplied file or folder name. It rejects
// separators, traversal segments, control characters, and reserved names.
func ValidateName(name string) error {
	trimmed := strings.TrimSpace(name)
	if trimmed == "" {
		return ErrEmptyName
	}
	if len(trimmed) > MaxNameLength {
		return ErrNameTooLong
	}
	if trimmed == "." || trimmed == ".." {
		return ErrInvalidSegment
	}
	if strings.ContainsAny(trimmed, `/\`) {
		return ErrInvalidSegment
	}
	if strings.ContainsRune(trimmed, 0) {
		return ErrInvalidSegment
	}
	for _, r := range trimmed {
		if unicode.IsControl(r) {
			return ErrInvalidSegment
		}
	}
	base := strings.ToLower(trimmed)
	if i := strings.IndexByte(base, '.'); i > 0 {
		base = base[:i]
	}
	if _, bad := reservedNames[base]; bad {
		return ErrInvalidSegment
	}
	return nil
}

// CleanName returns a name safe to write to disk, replacing anything
// ValidateName would reject rather than failing. Used for the browse mirror,
// where a best-effort readable name beats skipping the entry.
func CleanName(name string) string {
	var b strings.Builder
	for _, r := range name {
		switch {
		case r == '/' || r == '\\' || r == 0:
			b.WriteRune('_')
		case unicode.IsControl(r):
			b.WriteRune('_')
		default:
			b.WriteRune(r)
		}
	}
	out := strings.TrimSpace(b.String())
	out = strings.Trim(out, ".")
	if out == "" {
		out = "unnamed"
	}
	if len(out) > MaxNameLength {
		out = out[:MaxNameLength]
	}
	return out
}

// Join cleans root and rel, joins them, and verifies the result is still
// inside root. rel may contain separators; it may not escape.
func Join(root string, rel ...string) (string, error) {
	cleanRoot, err := filepath.Abs(filepath.Clean(root))
	if err != nil {
		return "", err
	}
	for _, seg := range rel {
		if strings.ContainsRune(seg, 0) {
			return "", ErrInvalidSegment
		}
	}
	joined := filepath.Join(append([]string{cleanRoot}, rel...)...)
	joined = filepath.Clean(joined)
	if !within(cleanRoot, joined) {
		return "", ErrEscapesRoot
	}
	return joined, nil
}

// Within reports whether child sits inside parent, treating equality as inside.
func Within(parent, child string) bool {
	p, err := filepath.Abs(filepath.Clean(parent))
	if err != nil {
		return false
	}
	c, err := filepath.Abs(filepath.Clean(child))
	if err != nil {
		return false
	}
	return within(p, c)
}

func within(parent, child string) bool {
	if child == parent {
		return true
	}
	rel, err := filepath.Rel(parent, child)
	if err != nil {
		return false
	}
	if rel == "." {
		return true
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return false
	}
	return !filepath.IsAbs(rel)
}
