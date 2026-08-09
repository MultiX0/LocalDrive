// Package httpapi wires every route onto chi and holds the handlers. Business
// rules live in the service packages; this layer only translates HTTP.
package httpapi

import (
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	tus "github.com/tus/tusd/v2/pkg/handler"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/auth"
	"github.com/MultiX0/LocalDrive/server/internal/config"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/discovery"
	"github.com/MultiX0/LocalDrive/server/internal/files"
	"github.com/MultiX0/LocalDrive/server/internal/jobs"
	"github.com/MultiX0/LocalDrive/server/internal/libraries"
	mw "github.com/MultiX0/LocalDrive/server/internal/middleware"
	"github.com/MultiX0/LocalDrive/server/internal/mounthelper"
	"github.com/MultiX0/LocalDrive/server/internal/settings"
	"github.com/MultiX0/LocalDrive/server/internal/shares"
	"github.com/MultiX0/LocalDrive/server/internal/thumbnails"
	"github.com/MultiX0/LocalDrive/server/internal/uploads"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

// Version is stamped at build time; it is reported by /status and /healthz.
var Version = "dev"

// API holds every dependency the handlers reach for.
type API struct {
	cfg        *config.Config
	log        *slog.Logger
	db         *db.DB
	auth       *auth.Service
	files      *files.Service
	shares     *shares.Service
	libs       *libraries.Service
	settings   *settings.Service
	audit      *audit.Logger
	hub        *ws.Hub
	pool       *jobs.Pool
	uploads    *uploads.Store
	tus        *tus.Handler
	mounts     *mounthelper.Client
	discovery  discovery.Announcer
	thumbs     *thumbnails.Generator
	apiLimiter *mw.Limiter
	authLimit  *mw.Limiter
	uploadSem  *mw.Semaphore
	startedAt  time.Time
}

// Deps is what New needs.
type Deps struct {
	Config      *config.Config
	Log         *slog.Logger
	DB          *db.DB
	Auth        *auth.Service
	Files       *files.Service
	Shares      *shares.Service
	Libraries   *libraries.Service
	Settings    *settings.Service
	Audit       *audit.Logger
	Hub         *ws.Hub
	Pool        *jobs.Pool
	Uploads     *uploads.Store
	MountHelper *mounthelper.Client
	Discovery   discovery.Announcer
	Thumbnails  *thumbnails.Generator
}

// New builds the API and its tus handler.
func New(d Deps) (*API, error) {
	log := d.Log
	if log == nil {
		log = slog.Default()
	}
	a := &API{
		cfg: d.Config, log: log, db: d.DB, auth: d.Auth, files: d.Files,
		shares: d.Shares, libs: d.Libraries, settings: d.Settings, audit: d.Audit,
		hub: d.Hub, pool: d.Pool, uploads: d.Uploads, mounts: d.MountHelper,
		discovery: d.Discovery, thumbs: d.Thumbnails,
		apiLimiter: mw.NewLimiter(30, 90),
		authLimit:  mw.NewLimiter(0.5, 10),
		uploadSem:  mw.NewSemaphore(d.Config.MaxUploadConcurrency),
		startedAt:  time.Now(),
	}

	tusHandler, err := uploads.NewHandler(uploads.HandlerDeps{
		Store:       d.Uploads,
		Files:       d.Files,
		Log:         log,
		BasePath:    "/api/v1/uploads/",
		MaxSize:     0,
		UserID:      mw.UserIDFrom,
		ClientIP:    mw.ClientIPFrom,
		CORSOrigins: d.Config.CORSAllowedOrigins,
	})
	if err != nil {
		return nil, err
	}
	a.tus = tusHandler
	return a, nil
}

// Close releases the limiters' janitors.
func (a *API) Close() {
	a.apiLimiter.Close()
	a.authLimit.Close()
}

// Router builds the whole route table.
func (a *API) Router() http.Handler {
	r := chi.NewRouter()

	r.Use(mw.RequestID)
	r.Use(mw.RealIP(true))
	r.Use(mw.Recover(a.log))
	r.Use(mw.Logger(a.log))
	r.Use(mw.SecurityHeaders)
	r.Use(mw.CORS(a.cfg.CORSAllowedOrigins))

	r.Get("/healthz", a.handleHealth)
	if a.cfg.MetricsEnabled {
		r.Get("/metrics", a.handleMetrics)
	}

	// public share access lives outside /api/v1 so a link is short enough to
	// read out loud
	r.Route("/s", func(r chi.Router) {
		r.Use(mw.RateLimit(a.apiLimiter, mw.ByIP))
		// served from this binary rather than a cdn, so opening a share link
		// tells nobody but this server that it happened
		r.Get("/assets/htmx.js", a.handleShareAsset)
		r.Get("/{token}", a.handleShareInfo)
		r.Post("/{token}", a.handleShareInfo)
		r.Get("/{token}/download", a.handleShareDownload)
		r.Get("/{token}/thumbnail", a.handleShareThumbnail)
		r.Get("/{token}/children", a.handleShareChildren)
	})

	r.Route("/api/v1", func(r chi.Router) {
		// unauthenticated
		r.Group(func(r chi.Router) {
			r.Use(mw.RateLimit(a.authLimit, mw.ByIP))
			r.Get("/status", a.handleStatus)
			r.Post("/setup", a.handleSetup)
			r.Post("/auth/register", a.handleRegister)
			r.Post("/auth/login", a.handleLogin)
			r.Post("/auth/refresh", a.handleRefresh)
			r.Get("/invites/{code}/check", a.handleCheckInvite)
		})

		// a device waiting for approval may poll its own status and nothing else
		r.Group(func(r chi.Router) {
			r.Use(a.requireToken(true))
			r.Get("/auth/session/{id}/status", a.handleSessionStatus)
		})

		// everything else needs a full-scope token
		r.Group(func(r chi.Router) {
			r.Use(a.requireToken(false))
			r.Use(mw.RateLimit(a.apiLimiter, mw.ByUser))

			// reachable even while the account is on a temporary password
			r.Patch("/me/password", a.handleChangePassword)
			r.Get("/me", a.handleMe)
			r.Post("/auth/logout", a.handleLogout)

			r.Group(func(r chi.Router) {
				r.Use(a.requirePasswordChanged)

				r.Patch("/me/profile", a.handleUpdateProfile)
				r.Post("/auth/2fa/begin", a.handleBeginTOTP)
				r.Post("/auth/2fa/verify", a.handleConfirmTOTP)
				r.Post("/auth/2fa/disable", a.handleDisableTOTP)

				r.Get("/users", a.handleListUsers)

				r.Get("/nodes", a.handleListNodes)
				r.Post("/nodes/folder", a.handleCreateFolder)
				r.Get("/nodes/{id}", a.handleGetNode)
				r.Get("/nodes/{id}/path", a.handleNodePath)
				r.Patch("/nodes/{id}", a.handlePatchNode)
				r.Delete("/nodes/{id}", a.handleTrashNode)
				r.Post("/nodes/{id}/restore", a.handleRestoreNode)
				r.Delete("/nodes/{id}/permanent", a.handleDeleteNode)
				r.Post("/nodes/{id}/star", a.handleStar)
				r.Delete("/nodes/{id}/star", a.handleUnstar)
				r.Get("/nodes/{id}/versions", a.handleListVersions)
				r.Post("/nodes/{id}/versions/{vid}/restore", a.handleRestoreVersion)

				r.Get("/nodes/{id}/shares", a.handleListNodeShares)
				r.Post("/nodes/{id}/share", a.handleCreateShare)
				r.Patch("/shares/{id}", a.handleUpdateShare)
				r.Delete("/shares/{id}", a.handleRevokeShare)
				r.Get("/shares", a.handleListMyShares)

				r.Get("/nodes/{id}/permissions", a.handleListGrants)
				r.Post("/nodes/{id}/permissions", a.handleGrantAccess)
				r.Delete("/nodes/{id}/permissions/{userID}", a.handleRevokeAccess)

				r.Get("/trash", a.handleListTrash)
				r.Get("/activity", a.handleActivity)

				r.Get("/libraries", a.handleListLibraries)
				r.Post("/libraries", a.handleRegisterLibrary)
				r.Patch("/libraries/{id}", a.handleRenameLibrary)
				r.Patch("/libraries/{id}/set-default", a.handleSetDefaultLibrary)
				r.Post("/libraries/{id}/eject", a.handleEjectLibrary)

				r.Get("/sessions", a.handleListSessions)
				r.Delete("/sessions/{id}", a.handleRevokeSession)
				r.Get("/devices/pending", a.handleListPendingDevices)
				r.Post("/devices/{id}/approve", a.handleApproveDevice)
				r.Post("/devices/{id}/deny", a.handleDenyDevice)

				r.Get("/server/settings", a.handleGetSettings)
				r.Patch("/server/settings", a.handleUpdateSettings)

				r.Route("/admin", func(r chi.Router) {
					r.Use(a.requireAdmin)
					r.Get("/users", a.handleAdminListUsers)
					r.Post("/users/{id}/reset-password", a.handleResetPassword)
					r.Patch("/users/{id}/role", a.handleSetRole)
					r.Patch("/users/{id}/quota", a.handleSetQuota)
					r.Patch("/users/{id}/disabled", a.handleSetDisabled)
					r.Get("/invites", a.handleListInvites)
					r.Post("/invites", a.handleCreateInvite)
					r.Delete("/invites/{id}", a.handleRevokeInvite)
					r.Get("/drives", a.handleListDrives)
					r.Post("/drives/{id}/mount", a.handleMountDrive)
					r.Post("/drives/{id}/format", a.handleFormatDrive)
					r.Post("/drives/pool", a.handlePoolDrives)
					r.Get("/devices/pending", a.handleAdminPendingDevices)
					r.Post("/devices/{id}/approve", a.handleApproveDevice)
					r.Post("/devices/{id}/deny", a.handleDenyDevice)
				})

				// tus does its own routing under this prefix
				r.Handle("/uploads", a.uploadHandler())
				r.Handle("/uploads/*", a.uploadHandler())
			})
		})

		// a browser cannot set a header on a websocket handshake, so this one
		// route also accepts the access token as a query parameter
		r.With(a.requireStreamToken).Get("/ws", a.handleWebSocket)

		// the three routes a media element loads directly. Same auth as the
		// rest, plus the query string door, because an img tag cannot send a
		// header and these are the only routes an img tag ever points at
		r.Group(func(r chi.Router) {
			r.Use(a.requireStreamToken)
			r.Use(mw.RateLimit(a.apiLimiter, mw.ByUser))
			r.Use(a.requirePasswordChanged)

			r.Get("/nodes/{id}/preview", a.handleFolderPreview)
			r.Get("/nodes/{id}/download", a.handleDownload)
			r.Get("/nodes/{id}/thumbnail", a.handleThumbnail)
		})
	})

	r.NotFound(func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusNotFound, "not_found", "no such endpoint")
	})
	r.MethodNotAllowed(func(w http.ResponseWriter, r *http.Request) {
		writeError(w, http.StatusMethodNotAllowed, "method_not_allowed", "that method is not allowed here")
	})
	return r
}

// uploadHandler bounds how many transfers one account may have in flight, then
// hands off to tus.
func (a *API) uploadHandler() http.Handler {
	strip := http.StripPrefix("/api/v1/uploads", a.tus)
	return mw.LimitConcurrency(a.uploadSem, mw.ByUser)(strip)
}

// requireToken verifies the bearer token and loads the account behind it.
// pendingOK allows the narrow scope a device waiting for approval carries.
func (a *API) requireToken(pendingOK bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw := bearerToken(r)
			if raw == "" {
				writeError(w, http.StatusUnauthorized, "unauthorized", "sign in first")
				return
			}
			claims, err := a.auth.Tokens().Parse(raw)
			if err != nil {
				writeError(w, http.StatusUnauthorized, "unauthorized", "sign in again")
				return
			}
			if claims.Scope == auth.ScopePending && !pendingOK {
				writeError(w, http.StatusForbidden, "device_pending",
					"this device is waiting to be approved")
				return
			}
			user, _, err := a.auth.ValidateSession(r.Context(), claims.Subject, claims.SessionID)
			if err != nil {
				a.fail(w, r, err)
				return
			}
			ctx := mw.WithUser(r.Context(), user)
			ctx = mw.WithSession(ctx, claims.SessionID)
			ctx = mw.WithScope(ctx, string(claims.Scope))
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// requireStreamToken is requireToken with one narrow addition: the token may
// arrive in the query string.
//
// Two kinds of route need that, both for the same reason. A browser cannot set
// a header on a websocket handshake, and an img, video or audio element cannot
// set one either: the element fetches the URL itself and there is no hook to
// add anything to it. Every other route keeps the header only.
//
// Only a full-scope token is accepted, so a device waiting for approval still
// cannot read a byte, and the server sends Referrer-Policy: no-referrer so a
// URL carrying one is not handed to anywhere else.
func (a *API) requireStreamToken(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := bearerToken(r)
		if raw == "" {
			raw = strings.TrimSpace(r.URL.Query().Get("access_token"))
		}
		if raw == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized", "sign in first")
			return
		}
		claims, err := a.auth.Tokens().Parse(raw)
		if err != nil || claims.Scope != auth.ScopeFull {
			writeError(w, http.StatusUnauthorized, "unauthorized", "sign in again")
			return
		}
		user, _, err := a.auth.ValidateSession(r.Context(), claims.Subject, claims.SessionID)
		if err != nil {
			a.fail(w, r, err)
			return
		}
		ctx := mw.WithUser(r.Context(), user)
		ctx = mw.WithSession(ctx, claims.SessionID)
		ctx = mw.WithScope(ctx, string(claims.Scope))
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// requirePasswordChanged blocks everything but reads and the password change
// while an account is still on a temporary credential.
func (a *API) requirePasswordChanged(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, ok := mw.UserFrom(r.Context())
		if !ok {
			writeError(w, http.StatusUnauthorized, "unauthorized", "sign in first")
			return
		}
		if user.MustChangePassword && !isReadOnly(r.Method) {
			writeError(w, http.StatusForbidden, "must_change_password",
				"choose a new password before doing anything else")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (a *API) requireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, ok := mw.UserFrom(r.Context())
		if !ok || !user.IsAdmin() {
			writeError(w, http.StatusForbidden, "forbidden", "that is an admin action")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func isReadOnly(method string) bool {
	return method == http.MethodGet || method == http.MethodHead || method == http.MethodOptions
}

func bearerToken(r *http.Request) string {
	header := r.Header.Get("Authorization")
	if header == "" {
		return ""
	}
	const prefix = "bearer "
	if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return ""
	}
	return strings.TrimSpace(header[len(prefix):])
}

// caller is the small helper every handler starts with.
func caller(r *http.Request) (string, string) {
	id, _ := mw.UserIDFrom(r.Context())
	return id, mw.ClientIPFrom(r.Context())
}
