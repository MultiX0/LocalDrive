package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

// Password rules, enforced identically on setup, register, change, and reset.
const (
	MinPasswordLength = 10
	MaxPasswordLength = 256
)

// ErrWeakPassword is returned when a password fails the length rule.
var ErrWeakPassword = fmt.Errorf("password must be between %d and %d characters", MinPasswordLength, MaxPasswordLength)

// ErrBadHash is returned for a stored hash that is not in the expected form.
var ErrBadHash = errors.New("auth: unrecognized password hash format")

// Hasher holds the tuned Argon2id cost, sized in config to stay inside the
// RAM budget.
type Hasher struct {
	memoryKiB uint32
	time      uint32
	threads   uint8
	keyLen    uint32
	saltLen   uint32
}

// NewHasher returns a Hasher with the given cost parameters.
func NewHasher(memoryKiB, timeCost uint32, threads uint8) *Hasher {
	return &Hasher{memoryKiB: memoryKiB, time: timeCost, threads: threads, keyLen: 32, saltLen: 16}
}

// ValidatePassword applies the length rule shared by every entry point.
func ValidatePassword(pw string) error {
	if len(pw) < MinPasswordLength || len(pw) > MaxPasswordLength {
		return ErrWeakPassword
	}
	return nil
}

// Hash returns the encoded Argon2id string stored in users.password_hash.
func (h *Hasher) Hash(password string) (string, error) {
	salt := make([]byte, h.saltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key := argon2.IDKey([]byte(password), salt, h.time, h.memoryKiB, h.threads, h.keyLen)
	return fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		argon2.Version, h.memoryKiB, h.time, h.threads,
		base64.RawStdEncoding.EncodeToString(salt),
		base64.RawStdEncoding.EncodeToString(key),
	), nil
}

// Verify checks a password against an encoded hash in constant time. It also
// reports whether the stored hash used weaker parameters than the current
// configuration, so a login can transparently upgrade it.
func (h *Hasher) Verify(encoded, password string) (ok bool, needsRehash bool, err error) {
	parts := strings.Split(encoded, "$")
	if len(parts) != 6 || parts[1] != "argon2id" {
		return false, false, ErrBadHash
	}
	var version int
	if _, err := fmt.Sscanf(parts[2], "v=%d", &version); err != nil {
		return false, false, ErrBadHash
	}
	if version != argon2.Version {
		return false, false, ErrBadHash
	}
	var memory, timeCost uint32
	var threads uint8
	if _, err := fmt.Sscanf(parts[3], "m=%d,t=%d,p=%d", &memory, &timeCost, &threads); err != nil {
		return false, false, ErrBadHash
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return false, false, ErrBadHash
	}
	want, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil {
		return false, false, ErrBadHash
	}
	got := argon2.IDKey([]byte(password), salt, timeCost, memory, threads, uint32(len(want)))
	if subtle.ConstantTimeCompare(got, want) != 1 {
		return false, false, nil
	}
	needsRehash = memory != h.memoryKiB || timeCost != h.time || threads != h.threads
	return true, needsRehash, nil
}
