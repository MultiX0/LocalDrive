package httpapi

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	mw "github.com/MultiX0/LocalDrive/server/internal/middleware"
)

func nowMillis() int64 { return db.NowMillis() }

func clientIP(r *http.Request) string { return mw.ClientIPFrom(r.Context()) }

// decodeQuiet reads an optional body, returning false rather than writing an
// error, for endpoints where a body is allowed but not required.
func decodeQuiet(r *http.Request, target any) bool {
	if r.Body == nil {
		return false
	}
	defer r.Body.Close()
	decoder := json.NewDecoder(io.LimitReader(r.Body, maxJSONBody))
	return decoder.Decode(target) == nil
}
