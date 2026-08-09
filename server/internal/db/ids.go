package db

import (
	"crypto/rand"
	"crypto/sha256"
	"database/sql"
	"encoding/base32"
	"encoding/base64"
	"encoding/hex"
	"strings"

	"github.com/google/uuid"
)

// NewID returns the identifier format every table uses.
func NewID() string { return uuid.NewString() }

// RandomToken returns n bytes of entropy, url-safe base64, for share links
// and refresh tokens.
func RandomToken(n int) string {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		panic("db: crypto/rand unavailable: " + err.Error())
	}
	return base64.RawURLEncoding.EncodeToString(buf)
}

// RandomCode returns a short, human-readable, unambiguous invite code.
func RandomCode(groups int) string {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	buf := make([]byte, groups*4)
	if _, err := rand.Read(buf); err != nil {
		panic("db: crypto/rand unavailable: " + err.Error())
	}
	var parts []string
	for g := 0; g < groups; g++ {
		var b strings.Builder
		for i := 0; i < 4; i++ {
			b.WriteByte(alphabet[int(buf[g*4+i])%len(alphabet)])
		}
		parts = append(parts, b.String())
	}
	return strings.Join(parts, "-")
}

// RandomBase32 is used for TOTP secrets, which must be base32 with no padding.
func RandomBase32(n int) string {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		panic("db: crypto/rand unavailable: " + err.Error())
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(buf)
}

// HashToken returns the at-rest form of a bearer-style secret.
func HashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// NullString wraps a plain string for a nullable column.
func NullString(s string) sql.NullString {
	return sql.NullString{String: s, Valid: s != ""}
}

// NullInt64 wraps a plain int64 for a nullable column, treating zero as null.
func NullInt64(v int64) sql.NullInt64 {
	return sql.NullInt64{Int64: v, Valid: v != 0}
}

// StringOrEmpty unwraps a nullable text column.
func StringOrEmpty(s sql.NullString) string {
	if s.Valid {
		return s.String
	}
	return ""
}

// Int64OrZero unwraps a nullable integer column.
func Int64OrZero(v sql.NullInt64) int64 {
	if v.Valid {
		return v.Int64
	}
	return 0
}
