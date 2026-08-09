// Package checksum wraps the one hash the storage layer uses, so the
// algorithm and its encoding live in exactly one place.
package checksum

import (
	"crypto/sha256"
	"encoding/hex"
	"hash"
	"io"
	"os"
	"regexp"
)

// CopyBufferSize is the fixed copy buffer used everywhere bytes stream to or
// from disk. Deliberately small; the server never buffers a whole file.
const CopyBufferSize = 32 * 1024

var hexPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)

// New returns a fresh sha256 hasher.
func New() hash.Hash { return sha256.New() }

// Sum encodes a hasher's digest the way the object store keys on it.
func Sum(h hash.Hash) string { return hex.EncodeToString(h.Sum(nil)) }

// Valid reports whether s is a well-formed lowercase hex sha256.
func Valid(s string) bool { return hexPattern.MatchString(s) }

// OfReader streams r through sha256 and returns the digest and byte count.
func OfReader(r io.Reader) (string, int64, error) {
	h := New()
	buf := make([]byte, CopyBufferSize)
	n, err := io.CopyBuffer(h, r, buf)
	if err != nil {
		return "", 0, err
	}
	return Sum(h), n, nil
}

// OfFile is OfReader over a path.
func OfFile(path string) (string, int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", 0, err
	}
	defer f.Close()
	return OfReader(f)
}

// TeeWriter wraps w so everything written through it is also hashed.
type TeeWriter struct {
	w io.Writer
	h hash.Hash
	n int64
}

// NewTeeWriter returns a TeeWriter over w.
func NewTeeWriter(w io.Writer) *TeeWriter {
	return &TeeWriter{w: w, h: New()}
}

func (t *TeeWriter) Write(p []byte) (int, error) {
	n, err := t.w.Write(p)
	if n > 0 {
		t.h.Write(p[:n])
		t.n += int64(n)
	}
	return n, err
}

// Sum returns the digest of everything written so far.
func (t *TeeWriter) Sum() string { return Sum(t.h) }

// Written returns the byte count written so far.
func (t *TeeWriter) Written() int64 { return t.n }
