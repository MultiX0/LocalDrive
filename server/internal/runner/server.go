// Package runner holds the entry point for every mode the single localdrive
// binary can run in. One binary, several processes: the privilege boundary is
// still the container each subcommand runs in, not the file on disk.
package runner

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/app"
	"github.com/MultiX0/LocalDrive/server/internal/config"
	"github.com/MultiX0/LocalDrive/server/internal/httpapi"
)

// RunServer serves the API. This is what the container runs, and it is also
// what a plain `localdrive serve` runs with no Docker anywhere in sight.
func RunServer(args []string) int {
	if err := runServer(args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		return 1
	}
	return 0
}

// RunHealthcheck is what the container HEALTHCHECK calls, so the image needs
// no curl or wget on it.
func RunHealthcheck(args []string) int { return runHealthcheck() }

func runServer(args []string) error {
	// an install directory next to the binary, or wherever LOCALDRIVE_HOME
	// points, supplies the settings. anything already in the environment wins,
	// which is what lets the container ignore all of this.
	if install, err := FindInstall(args); err == nil {
		if err := install.LoadEnv(); err != nil {
			return fmt.Errorf("read %s: %w", install.EnvPath, err)
		}
	}

	cfg, err := config.Load()
	if err != nil {
		return err
	}
	httpapi.Version = Version

	log := newServerLogger(cfg)
	slog.SetDefault(log)
	log.Info("starting local drive", "version", Version, "config", cfg.Redacted())
	if len(cfg.GeneratedSecrets) > 0 {
		log.Info("generated the secrets this server needed, and wrote them down",
			"keys", cfg.GeneratedSecrets,
			"file", config.DataDirFor(cfg.DBPath)+"/"+config.SecretsFileName)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	startCtx, cancelStart := context.WithTimeout(ctx, 60*time.Second)
	defer cancelStart()

	application, err := app.New(startCtx, cfg, log)
	if err != nil {
		return err
	}

	server := &http.Server{
		Addr:              cfg.Addr,
		Handler:           application.Handler(),
		ReadHeaderTimeout: 15 * time.Second,
		// no write timeout: a large download or a long resumable upload is a
		// normal request here, and a deadline would cut it off
		IdleTimeout: 120 * time.Second,
		BaseContext: func(net.Listener) context.Context { return context.Background() },
		ErrorLog:    slog.NewLogLogger(log.Handler(), slog.LevelWarn),
	}

	errCh := make(chan error, 1)
	running := []*http.Server{server}

	// A domain is what turns the built in certificate on. Without one this is
	// nil and nothing below runs: no extra listener, no acme client, no
	// certificate directory. The server listens on cfg.Addr over plain http
	// exactly as it did before any of this existed.
	auto, err := maybeAutoTLS(cfg)
	if err != nil {
		return err
	}

	if auto == nil {
		go func() {
			log.Info("listening", "addr", cfg.Addr)
			if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				errCh <- err
			}
		}()
	} else {
		auto.announce(ctx, log)
		listeners := auto.listeners(cfg.Addr, log)
		if len(listeners) == 0 {
			return fmt.Errorf("a domain is set but no https port could be opened; "+
				"binding %d needs privileges this process does not have", tlsPort)
		}
		running = running[:0]
		// the configured port answers plain http as well, so a request that
		// arrives in the clear has to be sorted out before it reaches the
		// application
		guarded := auto.guard(application.Handler())
		for _, ln := range listeners {
			srv := &http.Server{
				Handler:           guarded,
				ReadHeaderTimeout: 15 * time.Second,
				IdleTimeout:       120 * time.Second,
				BaseContext:       func(net.Listener) context.Context { return context.Background() },
				ErrorLog:          slog.NewLogLogger(log.Handler(), slog.LevelWarn),
			}
			running = append(running, srv)
			go func(s *http.Server, l net.Listener) {
				if err := s.Serve(l); err != nil && !errors.Is(err, http.ErrServerClosed) {
					errCh <- err
				}
			}(srv, ln)
		}
		// the challenge listener is how a certificate is issued at all, but a
		// busy port 80 should not stop the server that is already serving
		challenge := auto.challengeServer(log)
		running = append(running, challenge)
		go func() {
			if err := challenge.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
				log.Warn("no listener for the certificate challenge, renewal will fail",
					"port", acmePort, "error", err)
			}
		}()
	}

	select {
	case err := <-errCh:
		return err
	case <-ctx.Done():
		log.Info("shutting down")
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	for _, s := range running {
		if err := s.Shutdown(shutdownCtx); err != nil {
			log.Warn("http shutdown was not clean", "addr", s.Addr, "error", err)
		}
	}
	if err := application.Close(shutdownCtx); err != nil {
		log.Warn("service shutdown was not clean", "error", err)
	}
	log.Info("stopped")
	return nil
}

func newServerLogger(cfg *config.Config) *slog.Logger {
	level := slog.LevelInfo
	switch cfg.LogLevel {
	case "debug":
		level = slog.LevelDebug
	case "warn":
		level = slog.LevelWarn
	case "error":
		level = slog.LevelError
	}
	opts := &slog.HandlerOptions{Level: level}
	if cfg.Env == "dev" {
		return slog.New(slog.NewTextHandler(os.Stdout, opts))
	}
	return slog.New(slog.NewJSONHandler(os.Stdout, opts))
}

// healthcheck is what the container HEALTHCHECK runs, so the image needs no
// curl or wget on it.
func runHealthcheck() int {
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = ":8080"
	}
	if addr[0] == ':' {
		addr = "127.0.0.1" + addr
	}
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://" + addr + "/healthz")
	if err != nil {
		fmt.Fprintln(os.Stderr, "healthcheck failed:", err)
		return 1
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fmt.Fprintln(os.Stderr, "healthcheck returned", resp.Status)
		return 1
	}
	return 0
}
