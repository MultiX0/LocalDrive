package storage

import (
	"log/slog"
	"os"
	"path/filepath"
	"sync/atomic"

	"github.com/MultiX0/LocalDrive/server/pkg/pathsafe"
)

// Mirror maintains the read-only browse view: symlinks at
// browse/<user>/<folder path>/<file name> pointing at the real objects, so
// the drive stays meaningful in a plain file manager. It is a convenience
// view, never the source of truth, so every failure here is logged and
// swallowed rather than failing the operation that triggered it.
type Mirror struct {
	store    *Store
	log      *slog.Logger
	disabled atomic.Bool
}

// MirrorEntry is one file to represent in the browse view.
type MirrorEntry struct {
	Owner    string
	RelPath  []string // folder names from the user root down, already cleaned
	Name     string
	Checksum string
}

// NewMirror returns a Mirror over store.
func NewMirror(store *Store, log *slog.Logger) *Mirror {
	if log == nil {
		log = slog.Default()
	}
	return &Mirror{store: store, log: log}
}

// Disabled reports whether the mirror gave up, which happens on a filesystem
// that will not create symlinks. The rest of the server carries on unaffected.
func (m *Mirror) Disabled() bool { return m.disabled.Load() }

// Link points one browse path at its object.
func (m *Mirror) Link(root string, e MirrorEntry) {
	if m.disabled.Load() {
		return
	}
	target, err := m.store.ObjectPath(root, e.Checksum)
	if err != nil {
		return
	}
	linkPath, err := m.entryPath(root, e)
	if err != nil {
		return
	}
	if err := os.MkdirAll(filepath.Dir(linkPath), 0o750); err != nil {
		m.log.Debug("browse mirror directory failed", "error", err)
		return
	}
	if existing, err := os.Readlink(linkPath); err == nil {
		if existing == target {
			return
		}
		_ = os.Remove(linkPath)
	} else if _, statErr := os.Lstat(linkPath); statErr == nil {
		_ = os.Remove(linkPath)
	}
	if err := os.Symlink(target, linkPath); err != nil {
		if os.IsPermission(err) || isUnsupportedLink(err) {
			if m.disabled.CompareAndSwap(false, true) {
				m.log.Warn("browse mirror disabled, this filesystem does not allow symlinks", "error", err)
			}
			return
		}
		m.log.Debug("browse mirror link failed", "error", err)
	}
}

// Rebuild replaces one owner's whole browse subtree from scratch. Used by the
// periodic integrity job rather than on the hot path.
func (m *Mirror) Rebuild(root, owner string, entries []MirrorEntry) {
	if m.disabled.Load() {
		return
	}
	base, err := pathsafe.Join(root, BrowseDir, pathsafe.CleanName(owner))
	if err != nil {
		return
	}
	staging := base + ".rebuilding"
	_ = os.RemoveAll(staging)
	if err := os.MkdirAll(staging, 0o750); err != nil {
		m.log.Debug("browse mirror rebuild failed", "error", err)
		return
	}
	for _, e := range entries {
		target, err := m.store.ObjectPath(root, e.Checksum)
		if err != nil {
			continue
		}
		segs := append(cleanSegments(e.RelPath), pathsafe.CleanName(e.Name))
		linkPath, err := pathsafe.Join(staging, segs...)
		if err != nil {
			continue
		}
		if err := os.MkdirAll(filepath.Dir(linkPath), 0o750); err != nil {
			continue
		}
		if err := os.Symlink(target, linkPath); err != nil {
			if os.IsPermission(err) || isUnsupportedLink(err) {
				if m.disabled.CompareAndSwap(false, true) {
					m.log.Warn("browse mirror disabled, this filesystem does not allow symlinks", "error", err)
				}
				_ = os.RemoveAll(staging)
				return
			}
		}
	}
	old := base + ".old"
	_ = os.RemoveAll(old)
	if _, err := os.Stat(base); err == nil {
		if err := os.Rename(base, old); err != nil {
			_ = os.RemoveAll(staging)
			return
		}
	}
	if err := os.Rename(staging, base); err != nil {
		_ = os.Rename(old, base)
		_ = os.RemoveAll(staging)
		return
	}
	_ = os.RemoveAll(old)
}

func (m *Mirror) entryPath(root string, e MirrorEntry) (string, error) {
	segs := append([]string{BrowseDir, pathsafe.CleanName(e.Owner)}, cleanSegments(e.RelPath)...)
	segs = append(segs, pathsafe.CleanName(e.Name))
	return pathsafe.Join(root, segs...)
}

func cleanSegments(in []string) []string {
	out := make([]string, 0, len(in))
	for _, s := range in {
		out = append(out, pathsafe.CleanName(s))
	}
	return out
}

func isUnsupportedLink(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	for _, needle := range []string{"not supported", "privilege", "operation not permitted"} {
		if containsFold(msg, needle) {
			return true
		}
	}
	return false
}

func containsFold(haystack, needle string) bool {
	h := []rune(haystack)
	n := []rune(needle)
	if len(n) > len(h) {
		return false
	}
	lower := func(r rune) rune {
		if r >= 'A' && r <= 'Z' {
			return r + 32
		}
		return r
	}
	for i := 0; i+len(n) <= len(h); i++ {
		match := true
		for j := range n {
			if lower(h[i+j]) != lower(n[j]) {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}
	return false
}
