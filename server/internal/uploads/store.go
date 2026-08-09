// Package uploads implements a tus DataStore that writes straight into each
// library's staging directory, then adopts the finished bytes into the
// content-addressed object store. Nothing is ever buffered in memory.
package uploads

import (
	"context"
	"encoding"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/tus/tusd/v2/pkg/handler"

	"github.com/MultiX0/LocalDrive/server/internal/libraries"
	"github.com/MultiX0/LocalDrive/server/internal/storage"
	"github.com/MultiX0/LocalDrive/server/pkg/checksum"
	"github.com/MultiX0/LocalDrive/server/pkg/pathsafe"
)

// Metadata keys the client sends with Upload-Metadata.
const (
	MetaFilename  = "filename"
	MetaFiletype  = "filetype"
	MetaParentID  = "parent_id"
	MetaNodeID    = "node_id"
	MetaLibraryID = "library_id"
	MetaOwnerID   = "owner_id"
)

// AbandonedAfter is how long an unfinished upload survives before the sweep
// removes it. Generous on purpose: a phone can plausibly sit offline that long.
const AbandonedAfter = 7 * 24 * time.Hour

// Store is the tus DataStore.
type Store struct {
	libs *libraries.Service
	obj  *storage.Store
	log  *slog.Logger
}

// New returns a Store over the library set.
func New(libs *libraries.Service, obj *storage.Store, log *slog.Logger) *Store {
	if log == nil {
		log = slog.Default()
	}
	return &Store{libs: libs, obj: obj, log: log}
}

// UseIn registers this store and its extensions with a tusd composer.
func (s *Store) UseIn(composer *handler.StoreComposer) {
	composer.UseCore(s)
	composer.UseTerminater(s)
	composer.UseLengthDeferrer(s)
	composer.UseLocker(NewLocker())
}

type persistedInfo struct {
	Info      handler.FileInfo `json:"info"`
	HashState []byte           `json:"hash_state"`
}

// NewUpload creates the staging files for one upload.
func (s *Store) NewUpload(ctx context.Context, info handler.FileInfo) (handler.Upload, error) {
	if info.ID == "" {
		info.ID = newUploadID()
	}
	if err := validateUploadID(info.ID); err != nil {
		return nil, err
	}
	libraryID := info.MetaData[MetaLibraryID]
	if libraryID == "" {
		return nil, handler.NewError("ERR_NO_LIBRARY", "the upload did not resolve to a library", 400)
	}
	dir, err := s.stagingDir(libraryID)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return nil, err
	}
	binPath := filepath.Join(dir, info.ID+".bin")
	f, err := os.OpenFile(binPath, os.O_CREATE|os.O_WRONLY|os.O_EXCL, 0o640)
	if err != nil {
		return nil, err
	}
	f.Close()

	info.Storage = map[string]string{
		"Type":      "localdrive",
		"Path":      binPath,
		"LibraryID": libraryID,
	}
	u := &upload{store: s, info: info, binPath: binPath, infoPath: binPath + ".info"}
	if err := u.persist(); err != nil {
		os.Remove(binPath)
		return nil, err
	}
	return u, nil
}

// GetUpload reloads an upload by id, which makes a resume work after
// a process restart.
func (s *Store) GetUpload(ctx context.Context, id string) (handler.Upload, error) {
	if err := validateUploadID(id); err != nil {
		return nil, handler.ErrNotFound
	}
	for _, dir := range s.allStagingDirs() {
		binPath := filepath.Join(dir, id+".bin")
		infoPath := binPath + ".info"
		raw, err := os.ReadFile(infoPath)
		if err != nil {
			continue
		}
		var stored persistedInfo
		if err := json.Unmarshal(raw, &stored); err != nil {
			return nil, err
		}
		stat, err := os.Stat(binPath)
		if err != nil {
			return nil, handler.ErrNotFound
		}
		stored.Info.Offset = stat.Size()
		return &upload{
			store: s, info: stored.Info, hashState: stored.HashState,
			binPath: binPath, infoPath: infoPath,
		}, nil
	}
	return nil, handler.ErrNotFound
}

// AsTerminatableUpload lets a client cancel an upload.
func (s *Store) AsTerminatableUpload(u handler.Upload) handler.TerminatableUpload {
	return u.(*upload)
}

// AsLengthDeclarableUpload supports the creation-defer-length extension.
func (s *Store) AsLengthDeclarableUpload(u handler.Upload) handler.LengthDeclarableUpload {
	return u.(*upload)
}

func (s *Store) stagingDir(libraryID string) (string, error) {
	root, err := s.libs.Root(libraryID)
	if err != nil {
		return "", err
	}
	return s.obj.UploadsPath(root)
}

func (s *Store) allStagingDirs() []string {
	list, err := s.libs.List(context.Background())
	if err != nil {
		return nil
	}
	var dirs []string
	for _, lib := range list {
		if !lib.Online() {
			continue
		}
		if dir, err := s.obj.UploadsPath(lib.RootPath); err == nil {
			dirs = append(dirs, dir)
		}
	}
	return dirs
}

// Sweep removes unfinished uploads older than AbandonedAfter. It only ever
// touches staging bytes, never anything already committed as a real object.
func (s *Store) Sweep(ctx context.Context) error {
	cutoff := time.Now().Add(-AbandonedAfter)
	for _, dir := range s.allStagingDirs() {
		entries, err := os.ReadDir(dir)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			info, err := entry.Info()
			if err != nil || info.ModTime().After(cutoff) {
				continue
			}
			path := filepath.Join(dir, entry.Name())
			if err := os.Remove(path); err != nil {
				s.log.Debug("abandoned upload removal failed", "path", path, "error", err)
				continue
			}
			s.log.Info("removed an abandoned upload", "path", path)
		}
	}
	return nil
}

// upload is one in-progress transfer.
type upload struct {
	store     *Store
	info      handler.FileInfo
	hashState []byte
	binPath   string
	infoPath  string
}

func (u *upload) GetInfo(ctx context.Context) (handler.FileInfo, error) {
	return u.info, nil
}

// WriteChunk appends bytes at offset and carries the running sha256 forward,
// so a resumed upload does not have to rehash what it already sent.
func (u *upload) WriteChunk(ctx context.Context, offset int64, src io.Reader) (int64, error) {
	f, err := os.OpenFile(u.binPath, os.O_WRONLY|os.O_APPEND, 0o640)
	if err != nil {
		return 0, err
	}
	defer f.Close()

	stat, err := f.Stat()
	if err != nil {
		return 0, err
	}
	if stat.Size() != offset {
		return 0, handler.ErrMismatchOffset
	}

	hasher := checksum.New()
	if len(u.hashState) > 0 {
		if unmarshaler, ok := hasher.(encoding.BinaryUnmarshaler); ok {
			if err := unmarshaler.UnmarshalBinary(u.hashState); err != nil {
				return 0, fmt.Errorf("uploads: restore hash state: %w", err)
			}
		}
	}

	buf := make([]byte, checksum.CopyBufferSize)
	n, err := io.CopyBuffer(io.MultiWriter(f, hasher), src, buf)
	if n > 0 {
		u.info.Offset = offset + n
		if marshaler, ok := hasher.(encoding.BinaryMarshaler); ok {
			if state, mErr := marshaler.MarshalBinary(); mErr == nil {
				u.hashState = state
			}
		}
		if syncErr := f.Sync(); syncErr != nil && err == nil {
			err = syncErr
		}
		if pErr := u.persist(); pErr != nil && err == nil {
			err = pErr
		}
	}
	if err != nil {
		return n, err
	}
	return n, nil
}

func (u *upload) GetReader(ctx context.Context) (io.ReadCloser, error) {
	return os.Open(u.binPath)
}

// FinishUpload is a no-op: the commit runs in the handler's pre-finish
// callback so a failure there is reported to the client before it is told the
// upload succeeded.
func (u *upload) FinishUpload(ctx context.Context) error { return nil }

// Terminate discards a cancelled upload.
func (u *upload) Terminate(ctx context.Context) error {
	if err := os.Remove(u.binPath); err != nil && !os.IsNotExist(err) {
		return err
	}
	if err := os.Remove(u.infoPath); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}

// DeclareLength records a size that was not known when the upload started.
func (u *upload) DeclareLength(ctx context.Context, length int64) error {
	u.info.Size = length
	u.info.SizeIsDeferred = false
	return u.persist()
}

// Checksum returns the digest of everything written so far.
func (u *upload) Checksum() (string, error) {
	hasher := checksum.New()
	if len(u.hashState) == 0 {
		// nothing was streamed through this process; hash the staged file
		sum, _, err := checksum.OfFile(u.binPath)
		return sum, err
	}
	unmarshaler, ok := hasher.(encoding.BinaryUnmarshaler)
	if !ok {
		sum, _, err := checksum.OfFile(u.binPath)
		return sum, err
	}
	if err := unmarshaler.UnmarshalBinary(u.hashState); err != nil {
		sum, _, fallbackErr := checksum.OfFile(u.binPath)
		return sum, fallbackErr
	}
	return checksum.Sum(hasher), nil
}

// Paths exposes the staging file, for the commit step.
func (u *upload) Paths() (bin, info string) { return u.binPath, u.infoPath }

func (u *upload) persist() error {
	encoded, err := json.Marshal(persistedInfo{Info: u.info, HashState: u.hashState})
	if err != nil {
		return err
	}
	tmp := u.infoPath + ".tmp"
	if err := os.WriteFile(tmp, encoded, 0o640); err != nil {
		return err
	}
	return os.Rename(tmp, u.infoPath)
}

// Locker is the in-process lock tusd needs so two requests never write to one
// upload at the same time. A single server process is the whole deployment,
// so nothing external is required.
type Locker struct {
	mu    sync.Mutex
	locks map[string]*lockEntry
}

type lockEntry struct {
	held          bool
	requestUnlock func()
	released      chan struct{}
}

// NewLocker returns an empty Locker.
func NewLocker() *Locker {
	return &Locker{locks: map[string]*lockEntry{}}
}

// NewLock returns a lock handle for one upload id.
func (l *Locker) NewLock(id string) (handler.Lock, error) {
	return &uploadLock{locker: l, id: id}, nil
}

type uploadLock struct {
	locker *Locker
	id     string
}

func (l *uploadLock) Lock(ctx context.Context, requestUnlock func()) error {
	for {
		l.locker.mu.Lock()
		entry, exists := l.locker.locks[l.id]
		if !exists || !entry.held {
			l.locker.locks[l.id] = &lockEntry{
				held: true, requestUnlock: requestUnlock, released: make(chan struct{}),
			}
			l.locker.mu.Unlock()
			return nil
		}
		waiting := entry.released
		holderUnlock := entry.requestUnlock
		l.locker.mu.Unlock()

		if holderUnlock != nil {
			holderUnlock()
		}
		select {
		case <-waiting:
		case <-ctx.Done():
			return handler.ErrLockTimeout
		}
	}
}

func (l *uploadLock) Unlock() error {
	l.locker.mu.Lock()
	defer l.locker.mu.Unlock()
	entry, exists := l.locker.locks[l.id]
	if !exists {
		return nil
	}
	entry.held = false
	close(entry.released)
	delete(l.locker.locks, l.id)
	return nil
}

var errInvalidID = errors.New("uploads: invalid upload id")

func validateUploadID(id string) error {
	if id == "" || len(id) > 64 {
		return errInvalidID
	}
	for _, r := range id {
		switch {
		case r >= 'a' && r <= 'z':
		case r >= 'A' && r <= 'Z':
		case r >= '0' && r <= '9':
		case r == '-' || r == '_':
		default:
			return errInvalidID
		}
	}
	if err := pathsafe.ValidateName(id); err != nil {
		return errInvalidID
	}
	return nil
}

func newUploadID() string {
	return strings.ReplaceAll(randomID(), "=", "")
}
