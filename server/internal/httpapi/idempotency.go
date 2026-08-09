package httpapi

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	mw "github.com/MultiX0/LocalDrive/server/internal/middleware"
)

// idempotencyRetention is how long a stored response stays replayable. Long
// enough to cover a retry after a network blip, short enough that the table
// does not grow.
const idempotencyRetentionMillis = 24 * 60 * 60 * 1000

// replayIdempotent checks whether this exact create request already ran. A
// client that retried because the original response was lost gets the first
// result back rather than a second folder or a second share link.
func (a *API) replayIdempotent(w http.ResponseWriter, r *http.Request, endpoint string) (bool, bool) {
	key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key == "" || len(key) > 128 {
		return false, false
	}
	userID, ok := mw.UserIDFrom(r.Context())
	if !ok {
		return false, false
	}
	var stored string
	err := a.db.Read().QueryRowContext(r.Context(),
		`SELECT response_json FROM idempotency_keys WHERE key = ? AND user_id = ? AND endpoint = ?`,
		key, userID, endpoint).Scan(&stored)
	if errors.Is(err, sql.ErrNoRows) {
		return false, false
	}
	if err != nil {
		a.log.Debug("idempotency lookup failed", "error", err)
		return false, false
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Idempotent-Replay", "true")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(stored))
	return true, true
}

// storeIdempotent records a create response so a retry can replay it.
func (a *API) storeIdempotent(r *http.Request, endpoint string, payload any) {
	key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key == "" || len(key) > 128 {
		return
	}
	userID, ok := mw.UserIDFrom(r.Context())
	if !ok {
		return
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return
	}
	err = a.db.Write(r.Context(), func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `
			INSERT INTO idempotency_keys (key, user_id, endpoint, response_json, created_at)
			VALUES (?, ?, ?, ?, ?)
			ON CONFLICT (key, user_id, endpoint) DO NOTHING`,
			key, userID, endpoint, string(encoded), db.NowMillis())
		return err
	})
	if err != nil {
		a.log.Debug("idempotency store failed", "error", err)
	}
}

// PurgeIdempotencyKeys drops entries past their retention window.
func PurgeIdempotencyKeys(ctx context.Context, database *db.DB) error {
	cutoff := db.NowMillis() - idempotencyRetentionMillis
	return database.Write(ctx, func(ctx context.Context, tx *sql.Tx) error {
		_, err := tx.ExecContext(ctx, `DELETE FROM idempotency_keys WHERE created_at < ?`, cutoff)
		return err
	})
}
