// Package middleware holds the cross-cutting request layers: recovery,
// structured logging, CORS, rate limiting, and the auth context.
package middleware

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"runtime/debug"
	"strings"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/models"
)

type contextKey string

const (
	ctxUser      contextKey = "ld.user"
	ctxSession   contextKey = "ld.session"
	ctxScope     contextKey = "ld.scope"
	ctxClientIP  contextKey = "ld.ip"
	ctxRequestID contextKey = "ld.request_id"
)

// WithUser stores the authenticated account on the request context.
func WithUser(ctx context.Context, user models.User) context.Context {
	return context.WithValue(ctx, ctxUser, user)
}

// UserFrom returns the authenticated account, if there is one.
func UserFrom(ctx context.Context) (models.User, bool) {
	u, ok := ctx.Value(ctxUser).(models.User)
	return u, ok
}

// UserIDFrom returns just the account id, which is what most callers need.
func UserIDFrom(ctx context.Context) (string, bool) {
	u, ok := UserFrom(ctx)
	if !ok {
		return "", false
	}
	return u.ID, true
}

// WithSession stores the session id behind the current token.
func WithSession(ctx context.Context, sessionID string) context.Context {
	return context.WithValue(ctx, ctxSession, sessionID)
}

// SessionFrom returns the current session id.
func SessionFrom(ctx context.Context) string {
	id, _ := ctx.Value(ctxSession).(string)
	return id
}

// WithScope stores the token's scope, so the pending-device gate can check it.
func WithScope(ctx context.Context, scope string) context.Context {
	return context.WithValue(ctx, ctxScope, scope)
}

// WithClientIP stores the resolved client address.
func WithClientIP(ctx context.Context, ip string) context.Context {
	return context.WithValue(ctx, ctxClientIP, ip)
}

// ClientIPFrom returns the resolved client address.
func ClientIPFrom(ctx context.Context) string {
	ip, _ := ctx.Value(ctxClientIP).(string)
	return ip
}

// RequestIDFrom returns the per-request id used in logs.
func RequestIDFrom(ctx context.Context) string {
	id, _ := ctx.Value(ctxRequestID).(string)
	return id
}

// RealIP resolves the client address once and puts it on the context. Only
// the proxy's own forwarded header is trusted, and only when trustProxy is on.
func RealIP(trustProxy bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ip := directIP(r)
			if trustProxy {
				if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
					if first := strings.TrimSpace(strings.Split(forwarded, ",")[0]); first != "" {
						ip = first
					}
				} else if real := strings.TrimSpace(r.Header.Get("X-Real-IP")); real != "" {
					ip = real
				}
			}
			ctx := WithClientIP(r.Context(), ip)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func directIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// RequestID stamps every request so a log line can be traced.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := strings.TrimSpace(r.Header.Get("X-Request-Id"))
		if id == "" || len(id) > 64 {
			id = newRequestID()
		}
		ctx := context.WithValue(r.Context(), ctxRequestID, id)
		w.Header().Set("X-Request-Id", id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func newRequestID() string {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "req-" + time.Now().Format("150405.000000")
	}
	return "req-" + hex.EncodeToString(buf)
}

// Logger writes one structured line per request.
func Logger(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
			next.ServeHTTP(recorder, r)

			level := slog.LevelInfo
			switch {
			case recorder.status >= 500:
				level = slog.LevelError
			case recorder.status >= 400:
				level = slog.LevelWarn
			case r.URL.Path == "/healthz":
				level = slog.LevelDebug
			}
			userID := ""
			if u, ok := UserFrom(r.Context()); ok {
				userID = u.ID
			}
			log.Log(r.Context(), level, "request",
				"method", r.Method,
				"path", r.URL.Path,
				"status", recorder.status,
				"bytes", recorder.written,
				"duration_ms", time.Since(start).Milliseconds(),
				"ip", ClientIPFrom(r.Context()),
				"user", userID,
				"request_id", RequestIDFrom(r.Context()),
			)
		})
	}
}

type statusRecorder struct {
	http.ResponseWriter
	status  int
	written int64
	wrote   bool
}

func (r *statusRecorder) WriteHeader(status int) {
	if r.wrote {
		return
	}
	r.status = status
	r.wrote = true
	r.ResponseWriter.WriteHeader(status)
}

func (r *statusRecorder) Write(p []byte) (int, error) {
	if !r.wrote {
		r.WriteHeader(http.StatusOK)
	}
	n, err := r.ResponseWriter.Write(p)
	r.written += int64(n)
	return n, err
}

// Flush forwards to the wrapped writer so streamed responses still flush.
func (r *statusRecorder) Flush() {
	if f, ok := r.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// Unwrap lets anything using http.ResponseController reach the real writer.
func (r *statusRecorder) Unwrap() http.ResponseWriter { return r.ResponseWriter }

// Hijack hands the raw connection over for a websocket upgrade.
//
// Unwrap above is not enough on its own. It only helps callers that go through
// http.ResponseController, and the websocket library does a plain
// w.(http.Hijacker) type assertion instead. Without this method that assertion
// fails and every upgrade is answered with 501, which is silent on the server
// and looks to the app like a server that never sends events.
func (r *statusRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hijacker, ok := r.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("the underlying ResponseWriter cannot hijack")
	}
	// the connection stops being ours once it is hijacked, so record the
	// upgrade rather than leaving the log to report a 200 that never happened
	r.status = http.StatusSwitchingProtocols
	r.wrote = true
	return hijacker.Hijack()
}

// Recover turns a panic into a 500 with a logged stack instead of a dropped
// connection.
func Recover(log *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					if rec == http.ErrAbortHandler {
						panic(rec)
					}
					log.Error("panic serving request",
						"panic", rec,
						"path", r.URL.Path,
						"request_id", RequestIDFrom(r.Context()),
						"stack", string(debug.Stack()))
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusInternalServerError)
					_, _ = w.Write([]byte(`{"error":{"code":"internal","message":"something went wrong on the server"}}`))
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

// CORS decides which pages may talk to this server.
//
// Empty is the shipped default and means any origin: everyone runs their own
// server, and the client reaching it is a page somebody else hosts, so a list
// this server cannot know in advance is not a list it can enforce. Setting
// CORS_ALLOWED_ORIGINS is an operator deliberately narrowing that.
//
// The origin is reflected rather than answered with a wildcard, because a
// wildcard and Allow-Credentials are not allowed together and every request
// here carries a token.
func CORS(allowed []string) func(http.Handler) http.Handler {
	allowedSet := map[string]struct{}{}
	for _, o := range allowed {
		allowedSet[strings.TrimSuffix(o, "/")] = struct{}{}
	}
	allowAll := len(allowedSet) == 0
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := strings.TrimSuffix(r.Header.Get("Origin"), "/")
			if origin != "" {
				_, listed := allowedSet[origin]
				if allowAll || listed {
					w.Header().Set("Access-Control-Allow-Origin", origin)
					w.Header().Set("Vary", "Origin")
					w.Header().Set("Access-Control-Allow-Credentials", "true")
					w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, HEAD, OPTIONS")
					// Range is what a video element sends to seek, and without it
					// listed the preflight fails and playback never starts
					w.Header().Set("Access-Control-Allow-Headers",
						"Authorization, Content-Type, Idempotency-Key, X-Request-Id, Range, If-None-Match, If-Modified-Since, "+
							"Tus-Resumable, Upload-Length, Upload-Offset, Upload-Metadata, Upload-Defer-Length, X-CSRF-Token")
					// a cross-origin response hides every header not named here,
					// so a download loses its filename and a video its length
					w.Header().Set("Access-Control-Expose-Headers",
						"Location, Upload-Offset, Upload-Length, Tus-Resumable, Tus-Version, "+
							"Tus-Extension, Tus-Max-Size, Local-Drive-Node-Id, X-Request-Id, "+
							"Content-Length, Content-Range, Accept-Ranges, Content-Disposition, ETag, Last-Modified")
					w.Header().Set("Access-Control-Max-Age", "86400")
				}
			}
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// SecurityHeaders sets the small set that matters for an API plus a served
// web build.
//
// crossOrigin relaxes Cross-Origin-Resource-Policy from same-site.
//
// A thumbnail, a video and an audio file are fetched by the element itself,
// and same-site makes the browser refuse the response outright for a web
// client served from anywhere but this server: every picture becomes a broken
// image with no error a person could act on. That is the whole point of
// allowing an origin in the first place, so the two settings move together.
func SecurityHeaders(crossOrigin bool) func(http.Handler) http.Handler {
	policy := "same-site"
	if crossOrigin {
		policy = "cross-origin"
	}
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("X-Content-Type-Options", "nosniff")
			w.Header().Set("X-Frame-Options", "DENY")
			w.Header().Set("Referrer-Policy", "no-referrer")
			w.Header().Set("Cross-Origin-Resource-Policy", policy)
			next.ServeHTTP(w, r)
		})
	}
}
