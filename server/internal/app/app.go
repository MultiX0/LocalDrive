// Package app wires every service together once, so the server binary and the
// integration tests build the exact same stack.
package app

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/audit"
	"github.com/MultiX0/LocalDrive/server/internal/auth"
	"github.com/MultiX0/LocalDrive/server/internal/config"
	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/discovery"
	"github.com/MultiX0/LocalDrive/server/internal/files"
	"github.com/MultiX0/LocalDrive/server/internal/httpapi"
	"github.com/MultiX0/LocalDrive/server/internal/jobs"
	"github.com/MultiX0/LocalDrive/server/internal/libraries"
	"github.com/MultiX0/LocalDrive/server/internal/media"
	"github.com/MultiX0/LocalDrive/server/internal/models"
	"github.com/MultiX0/LocalDrive/server/internal/mounthelper"
	"github.com/MultiX0/LocalDrive/server/internal/settings"
	"github.com/MultiX0/LocalDrive/server/internal/shares"
	"github.com/MultiX0/LocalDrive/server/internal/storage"
	"github.com/MultiX0/LocalDrive/server/internal/thumbnails"
	"github.com/MultiX0/LocalDrive/server/internal/uploads"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

// App is the assembled server.
type App struct {
	Config    *config.Config
	Log       *slog.Logger
	DB        *db.DB
	Settings  *settings.Service
	Auth      *auth.Service
	Files     *files.Service
	Shares    *shares.Service
	Libraries *libraries.Service
	Hub       *ws.Hub
	Pool      *jobs.Pool
	Scheduler *jobs.Scheduler
	API       *httpapi.API
	Uploads   *uploads.Store

	handler http.Handler
}

// New builds every service and returns a ready App. Nothing starts serving
// until Handler is mounted on a server.
func New(ctx context.Context, cfg *config.Config, log *slog.Logger) (*App, error) {
	if log == nil {
		log = slog.Default()
	}

	// Said out loud on every start, because "where are my files" is the first
	// question anyone asks of a server they are trusting with them, and the
	// answer should not require reading the source or knowing what an
	// environment variable is.
	log.Info("using data directory",
		"database", cfg.DBPath,
		"library", cfg.LibraryPath,
	)

	database, err := db.Open(ctx, db.Options{
		Path: cfg.DBPath, MaxReadConns: cfg.MaxReadConns, Logger: log,
	})
	if err != nil {
		return nil, err
	}
	if err := database.Migrate(ctx); err != nil {
		database.Close()
		return nil, err
	}

	settingsSvc, err := settings.New(ctx, database, settings.Defaults{
		ServerName:            "Local Drive",
		RequireDeviceApproval: cfg.RequireDeviceApprovalDefault,
		EnableLANDiscovery:    cfg.EnableLANDiscoveryDefault,
		AllowSelfRegistration: cfg.AllowSelfRegistrationDefault,
		TrashRetentionDays:    cfg.TrashRetentionDays,
		VersionRetentionCount: cfg.VersionRetentionCount,
		VersionRetentionDays:  cfg.VersionRetentionDays,
	})
	if err != nil {
		database.Close()
		return nil, err
	}

	auditLog := audit.New(database, log)
	hub := ws.NewHub(log)
	pool := jobs.NewPool(cfg.WorkerPoolSize, 512, log)
	scheduler := jobs.NewScheduler(log)

	store := storage.New()
	mirror := storage.NewMirror(store, log)

	libs, err := libraries.New(ctx, database, store, log)
	if err != nil {
		return nil, closeAll(database, hub, pool, err)
	}
	if err := ensureDefaultLibrary(ctx, libs, cfg); err != nil {
		return nil, closeAll(database, hub, pool, err)
	}

	hasher := auth.NewHasher(cfg.Argon2Memory, cfg.Argon2Time, cfg.Argon2Threads)
	tokens := auth.NewTokenIssuer(cfg.JWTSecret, cfg.AccessTokenTTL, "local-drive")
	authSvc := auth.New(auth.Deps{
		DB: database, Hasher: hasher, Tokens: tokens, Settings: settingsSvc,
		Audit: auditLog, Hub: hub, Log: log,
		RefreshTTL: cfg.RefreshTokenTTL, DefaultQuota: cfg.DefaultQuotaBytes,
	})

	// a locked-out admin is recovered before a single request is served
	dataDir := filepath.Dir(cfg.DBPath)
	if err := authSvc.ConsumeRecoveryMarker(ctx, dataDir, log); err != nil {
		log.Error("recovery marker could not be applied", "error", err)
	}

	filesSvc := files.New(files.Deps{
		DB: database, Store: store, Mirror: mirror, Libs: libs, Hub: hub,
		Audit: auditLog, Pool: pool, Settings: settingsSvc, Log: log,
	})

	tempDir := filepath.Join(os.TempDir(), "localdrive")
	if err := os.MkdirAll(tempDir, 0o750); err != nil {
		log.Warn("could not create a scratch directory, thumbnails may be skipped", "error", err)
	}
	generator := thumbnails.Probe(log, tempDir)
	filesSvc.SetThumbnailer(func(ctx context.Context, node models.Node, root string) error {
		if !generator.Supports(node.MimeType) {
			return thumbnails.ErrUnsupported
		}
		f, _, err := store.Open(root, node.ChecksumSHA256)
		if err != nil {
			return err
		}
		sourcePath := f.Name()
		f.Close()
		data, err := generator.Generate(ctx, sourcePath, node.MimeType)
		if err != nil {
			return err
		}
		return store.WriteThumbnail(root, node.ID, data)
	})
	filesSvc.SetThumbnailSupport(generator.Supports)

	// go back for whatever was uploaded while ffmpeg was missing, or a video
	// from the server's first minute keeps a type badge forever
	generator.OnFFmpegReady(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		queued, err := filesSvc.BackfillThumbnails(ctx, 100)
		if err != nil {
			log.Warn("could not queue the missed video previews", "error", err)
			return
		}
		if queued > 0 {
			log.Info("queued previews for files uploaded before ffmpeg arrived", "count", queued)
		}
	})

	// dimensions and capture time, read from the file's own header. Wired
	// separately from the thumbnailer because a picture too odd to render a
	// preview for still has both, and a photo grid needs them more
	filesSvc.SetMediaProbe(func(path string) (int, int, int64, error) {
		info, err := media.Probe(path)
		if err != nil {
			return 0, 0, 0, err
		}
		return info.Width, info.Height, info.TakenAt, nil
	})

	sharesSvc := shares.New(shares.Deps{
		DB: database, Files: filesSvc, Hasher: hasher, Audit: auditLog,
		Hub: hub, Log: log, BaseURL: cfg.PublicBaseURL,
	})

	uploadStore := uploads.New(libs, store, log)
	mountClient := mounthelper.NewClient(cfg.MountHelperSocket, cfg.MountHelperSharedSecret)
	// With a socket configured the announcer lives in the helper container,
	// because a container cannot put multicast onto the real LAN. Without one
	// the server is running directly on the machine and its network is the one
	// the phones are on, so it announces itself rather than needing a second
	// process that would have nothing to work around.
	var discoveryClient discovery.Announcer
	if cfg.LANDiscoverySocket != "" && cfg.LANDiscoverySecret != "" {
		discoveryClient = discovery.NewClient(cfg.LANDiscoverySocket, cfg.LANDiscoverySecret)
	} else {
		discoveryClient = discovery.NewLocalAnnouncer(log, portOf(cfg.Addr))
	}

	api, err := httpapi.New(httpapi.Deps{
		Config: cfg, Log: log, DB: database, Auth: authSvc, Files: filesSvc,
		Shares: sharesSvc, Libraries: libs, Settings: settingsSvc, Audit: auditLog,
		Hub: hub, Pool: pool, Uploads: uploadStore, MountHelper: mountClient,
		Discovery: discoveryClient, Thumbnails: generator,
	})
	if err != nil {
		return nil, closeAll(database, hub, pool, err)
	}

	a := &App{
		Config: cfg, Log: log, DB: database, Settings: settingsSvc, Auth: authSvc,
		Files: filesSvc, Shares: sharesSvc, Libraries: libs, Hub: hub, Pool: pool,
		Scheduler: scheduler, API: api, Uploads: uploadStore,
		handler: api.Router(),
	}

	a.registerScheduledJobs(sharesSvc, uploadStore, libs, authSvc, database, log)
	scheduler.Start()

	// keep the lan-discovery bridge in step with the admin-editable settings
	settingsSvc.Watch(func(current models.ServerSettings) {
		if !discoveryClient.Enabled() {
			return
		}
		go func() {
			pushCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			ready := false
			if list, err := libs.List(pushCtx); err == nil {
				for _, lib := range list {
					if lib.Online() {
						ready = true
						break
					}
				}
			}
			if err := discoveryClient.Advertise(pushCtx, discovery.Advertisement{
				Enabled: current.EnableLANDiscovery, ServerID: current.ServerID,
				Name: current.ServerName, Version: httpapi.Version, Ready: ready,
			}); err != nil {
				log.Debug("initial lan discovery push failed", "error", err)
			}
		}()
	})

	return a, nil
}

// Handler returns the full router.
func (a *App) Handler() http.Handler { return a.handler }

// registerScheduledJobs sets up the periodic hygiene passes described in the
// plan's background jobs section.
func (a *App) registerScheduledJobs(
	sharesSvc *shares.Service,
	uploadStore *uploads.Store,
	libs *libraries.Service,
	authSvc *auth.Service,
	database *db.DB,
	log *slog.Logger,
) {
	a.Scheduler.Every("share expiry sweep", 15*time.Minute, 30*time.Second, sharesSvc.SweepExpired)

	a.Scheduler.Every("library probe", 20*time.Second, 5*time.Second, func(ctx context.Context) error {
		offline, online, err := libs.Probe(ctx)
		if err != nil {
			return err
		}
		for _, id := range offline {
			log.Warn("a library went offline, its drive is not connected", "library", id)
		}
		for _, id := range online {
			log.Info("a library came back online", "library", id)
		}
		return nil
	})

	// The callback above covers ffmpeg arriving. This covers the rest: a first
	// attempt that failed, an upload during a restart, a library that was
	// offline. Small batches, so a big library heals over hours.
	a.Scheduler.Every("missing preview sweep", 30*time.Minute, 90*time.Second,
		func(ctx context.Context) error {
			queued, err := a.Files.BackfillThumbnails(ctx, 50)
			if err == nil && queued > 0 {
				log.Info("queued missing previews", "count", queued)
			}
			return err
		})

	a.Scheduler.Every("trash purge", 6*time.Hour, 2*time.Minute, func(ctx context.Context) error {
		return a.Files.PurgeTrash(ctx, a.Settings.Get().TrashRetentionDays)
	})

	a.Scheduler.Every("version pruning", 12*time.Hour, 3*time.Minute, func(ctx context.Context) error {
		cfg := a.Settings.Get()
		return a.Files.PruneVersions(ctx, cfg.VersionRetentionCount, cfg.VersionRetentionDays)
	})

	a.Scheduler.Every("abandoned upload sweep", 6*time.Hour, 4*time.Minute, uploadStore.Sweep)

	a.Scheduler.Every("quota recalculation", 24*time.Hour, 10*time.Minute, func(ctx context.Context) error {
		if err := a.Files.RecalculateQuotas(ctx); err != nil {
			return err
		}
		return libs.RecalculateUsage(ctx)
	})

	a.Scheduler.Every("session cleanup", 12*time.Hour, 5*time.Minute, func(ctx context.Context) error {
		return authSvc.PurgeStaleSessions(ctx, int64(90*24*time.Hour/time.Millisecond))
	})

	a.Scheduler.Every("idempotency key cleanup", 6*time.Hour, 6*time.Minute, func(ctx context.Context) error {
		return httpapi.PurgeIdempotencyKeys(ctx, database)
	})

	a.Scheduler.Every("storage integrity check", 24*time.Hour, 15*time.Minute, func(ctx context.Context) error {
		return a.Files.VerifyIntegrity(ctx)
	})
}

// Close shuts everything down in the right order: stop taking new work, drain
// what is running, then close the database last.
func (a *App) Close(ctx context.Context) error {
	var firstErr error
	record := func(err error) {
		if err != nil && firstErr == nil {
			firstErr = err
		}
	}
	record(a.Scheduler.Stop(ctx))
	record(a.Pool.Close(ctx))
	record(a.Hub.Close(ctx))
	a.API.Close()
	// Close checkpoints on its way out, once the readers holding the log open
	// are gone. Doing it here as well only ever found the database still busy.
	record(a.DB.Close())
	return firstErr
}

// ensureDefaultLibrary guarantees there is somewhere for content to land on a
// brand new deployment.
func ensureDefaultLibrary(ctx context.Context, libs *libraries.Service, cfg *config.Config) error {
	list, err := libs.List(ctx)
	if err != nil {
		return err
	}
	if len(list) > 0 {
		return nil
	}
	_, err = libs.Register(ctx, libraries.RegisterOptions{
		Name:        "This server",
		RootPath:    cfg.LibraryPath,
		Kind:        models.LibraryInternal,
		MakeDefault: true,
	})
	if err != nil && !errors.Is(err, libraries.ErrDuplicate) {
		return fmt.Errorf("app: create the default library: %w", err)
	}
	return nil
}

func closeAll(database *db.DB, hub *ws.Hub, pool *jobs.Pool, cause error) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = pool.Close(ctx)
	_ = hub.Close(ctx)
	_ = database.Close()
	return cause
}

// portOf reads the port out of a listen address like ":7443" or "0.0.0.0:7443",
// so the advertisement carries the port the apps should actually connect to.
func portOf(addr string) int {
	_, portText, err := net.SplitHostPort(addr)
	if err != nil {
		return 7443
	}
	port, err := strconv.Atoi(portText)
	if err != nil || port <= 0 {
		return 7443
	}
	return port
}
