// Package storage is the content-addressed object store: every file lives
// once at objects/<aa>/<bb>/<sha256> under its own library root, written to a
// temp path first and renamed into place so a crash never leaves a
// half-written object where a reader could find it.
package storage

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/MultiX0/LocalDrive/server/pkg/checksum"
	"github.com/MultiX0/LocalDrive/server/pkg/pathsafe"
)

// Directory names inside a library root.
const (
	ObjectsDir    = "objects"
	InternalDir   = ".localdrive"
	VersionsDir   = "versions"
	ThumbnailsDir = "thumbnails"
	UploadsDir    = "uploads"
	TempDir       = "tmp"
	BrowseDir     = "browse"
)

// ErrNotFound is returned when an object is absent from a library.
var ErrNotFound = errors.New("storage: object not found")

// ErrChecksumMismatch is returned when written bytes do not hash to what the
// caller declared.
var ErrChecksumMismatch = errors.New("storage: checksum mismatch")

// Store operates on one library root at a time; the root is always passed in
// so nothing here can reach across a library boundary.
type Store struct{}

// New returns a Store. It holds no state; libraries are addressed by root.
func New() *Store { return &Store{} }

// Prepare creates the directory skeleton a library needs.
func (s *Store) Prepare(root string) error {
	dirs := []string{
		filepath.Join(root, ObjectsDir),
		filepath.Join(root, InternalDir, VersionsDir),
		filepath.Join(root, InternalDir, ThumbnailsDir),
		filepath.Join(root, InternalDir, UploadsDir),
		filepath.Join(root, InternalDir, TempDir),
		filepath.Join(root, BrowseDir),
	}
	for _, d := range dirs {
		if err := os.MkdirAll(d, 0o750); err != nil {
			return fmt.Errorf("storage: prepare %s: %w", d, err)
		}
	}
	return nil
}

// ObjectPath returns the on-disk location of one object, verified to be
// inside root.
func (s *Store) ObjectPath(root, sum string) (string, error) {
	if !checksum.Valid(sum) {
		return "", fmt.Errorf("storage: invalid checksum %q", sum)
	}
	return pathsafe.Join(root, ObjectsDir, sum[0:2], sum[2:4], sum)
}

// ThumbnailPath returns where a node's cached preview lives.
func (s *Store) ThumbnailPath(root, nodeID string) (string, error) {
	if err := pathsafe.ValidateName(nodeID); err != nil {
		return "", err
	}
	return pathsafe.Join(root, InternalDir, ThumbnailsDir, nodeID+".jpg")
}

// UploadsPath returns the staging directory for in-progress tus uploads.
func (s *Store) UploadsPath(root string) (string, error) {
	return pathsafe.Join(root, InternalDir, UploadsDir)
}

// Exists reports whether an object is present.
func (s *Store) Exists(root, sum string) (bool, int64, error) {
	p, err := s.ObjectPath(root, sum)
	if err != nil {
		return false, 0, err
	}
	info, err := os.Stat(p)
	if err != nil {
		if os.IsNotExist(err) {
			return false, 0, nil
		}
		return false, 0, err
	}
	return true, info.Size(), nil
}

// Open returns a readable handle on an object.
func (s *Store) Open(root, sum string) (*os.File, os.FileInfo, error) {
	p, err := s.ObjectPath(root, sum)
	if err != nil {
		return nil, nil, err
	}
	f, err := os.Open(p)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil, ErrNotFound
		}
		return nil, nil, err
	}
	info, err := f.Stat()
	if err != nil {
		f.Close()
		return nil, nil, err
	}
	return f, info, nil
}

// Write streams r into the store and returns its checksum and size. The bytes
// land at a temp path, get fsynced, and are only then renamed into their final
// content-addressed location.
func (s *Store) Write(root string, r io.Reader) (sum string, size int64, err error) {
	tmpDir, err := pathsafe.Join(root, InternalDir, TempDir)
	if err != nil {
		return "", 0, err
	}
	if err := os.MkdirAll(tmpDir, 0o750); err != nil {
		return "", 0, err
	}
	tmp, err := os.CreateTemp(tmpDir, "obj-*.part")
	if err != nil {
		return "", 0, err
	}
	tmpName := tmp.Name()
	defer func() {
		if err != nil {
			tmp.Close()
			os.Remove(tmpName)
		}
	}()

	tee := checksum.NewTeeWriter(tmp)
	buf := make([]byte, checksum.CopyBufferSize)
	if _, err = io.CopyBuffer(tee, r, buf); err != nil {
		return "", 0, err
	}
	if err = tmp.Sync(); err != nil {
		return "", 0, err
	}
	if err = tmp.Close(); err != nil {
		return "", 0, err
	}
	sum = tee.Sum()
	size = tee.Written()
	if err = s.Adopt(root, tmpName, sum); err != nil {
		return "", 0, err
	}
	return sum, size, nil
}

// Adopt moves an already-written file at tmpPath into the object store under
// sum. It is the commit half of a resumable upload, where the bytes were
// streamed to disk over many requests rather than in one pass.
func (s *Store) Adopt(root, tmpPath, sum string) error {
	dest, err := s.ObjectPath(root, sum)
	if err != nil {
		return err
	}
	if _, statErr := os.Stat(dest); statErr == nil {
		// deduplicated: the object is already here, drop the duplicate bytes
		return os.Remove(tmpPath)
	}
	if err := os.MkdirAll(filepath.Dir(dest), 0o750); err != nil {
		return err
	}
	if err := os.Rename(tmpPath, dest); err != nil {
		if !isCrossDevice(err) {
			return err
		}
		if err := copyFile(tmpPath, dest); err != nil {
			return err
		}
		return os.Remove(tmpPath)
	}
	if err := os.Chmod(dest, 0o640); err != nil && !os.IsNotExist(err) {
		return err
	}
	return syncDir(filepath.Dir(dest))
}

// Verify rehashes an object on disk and compares it to its expected digest.
func (s *Store) Verify(root, sum string) error {
	p, err := s.ObjectPath(root, sum)
	if err != nil {
		return err
	}
	actual, _, err := checksum.OfFile(p)
	if err != nil {
		if os.IsNotExist(err) {
			return ErrNotFound
		}
		return err
	}
	if actual != sum {
		return fmt.Errorf("%w: %s has digest %s", ErrChecksumMismatch, sum, actual)
	}
	return nil
}

// Remove deletes one object. Callers must have already established that no
// node or version still references it; deduplication makes that check the
// caller's responsibility, not this package's.
func (s *Store) Remove(root, sum string) error {
	p, err := s.ObjectPath(root, sum)
	if err != nil {
		return err
	}
	if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
		return err
	}
	// prune the two fan-out directories when they empty out
	dir := filepath.Dir(p)
	_ = os.Remove(dir)
	_ = os.Remove(filepath.Dir(dir))
	return nil
}

// WriteThumbnail stores a generated preview for a node.
func (s *Store) WriteThumbnail(root, nodeID string, data []byte) error {
	p, err := s.ThumbnailPath(root, nodeID)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o750); err != nil {
		return err
	}
	tmp := p + ".tmp"
	if err := os.WriteFile(tmp, data, 0o640); err != nil {
		return err
	}
	return os.Rename(tmp, p)
}

// RemoveThumbnail deletes a node's cached preview if it has one.
func (s *Store) RemoveThumbnail(root, nodeID string) error {
	p, err := s.ThumbnailPath(root, nodeID)
	if err != nil {
		return err
	}
	if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

// FreeSpace reports total and free bytes on the filesystem backing root.
func (s *Store) FreeSpace(root string) (total, free int64, err error) {
	return diskUsage(root)
}

// SameDevice reports whether root still resolves to the device it did when
// the library was registered. Cheap enough to poll, and it is how an
// unplugged drive is noticed without asking the mount helper.
func (s *Store) SameDevice(root, deviceID string) (string, bool, error) {
	current, err := deviceIdentity(root)
	if err != nil {
		return "", false, err
	}
	if deviceID == "" {
		return current, true, nil
	}
	return current, current == deviceID, nil
}

// DeviceIdentity returns an opaque identity for the device backing root.
func (s *Store) DeviceIdentity(root string) (string, error) {
	return deviceIdentity(root)
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	tmp := dst + ".copying"
	out, err := os.OpenFile(tmp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o640)
	if err != nil {
		return err
	}
	buf := make([]byte, checksum.CopyBufferSize)
	if _, err := io.CopyBuffer(out, in, buf); err != nil {
		out.Close()
		os.Remove(tmp)
		return err
	}
	if err := out.Sync(); err != nil {
		out.Close()
		os.Remove(tmp)
		return err
	}
	if err := out.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, dst)
}

func syncDir(dir string) error {
	f, err := os.Open(dir)
	if err != nil {
		return nil // directory fsync is best effort, not every platform allows it
	}
	defer f.Close()
	if err := f.Sync(); err != nil && !strings.Contains(err.Error(), "not supported") {
		return nil
	}
	return nil
}
