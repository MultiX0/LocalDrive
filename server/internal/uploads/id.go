package uploads

import (
	"crypto/rand"
	"encoding/base64"
)

// randomID returns the opaque id a tus upload is addressed by.
func randomID() string {
	buf := make([]byte, 18)
	if _, err := rand.Read(buf); err != nil {
		panic("uploads: crypto/rand unavailable: " + err.Error())
	}
	return base64.RawURLEncoding.EncodeToString(buf)
}
