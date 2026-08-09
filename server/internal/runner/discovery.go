package runner

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/hashicorp/mdns"

	"github.com/MultiX0/LocalDrive/server/internal/discovery"
)

// ServiceName is what a client browses for during onboarding.
const ServiceName = "_localdrive._tcp"

type bridge struct {
	log    *slog.Logger
	secret string

	mu      sync.Mutex
	server  *mdns.Server
	current discovery.Advertisement
}

// RunDiscovery answers mDNS queries on the physical LAN.
func RunDiscovery(args []string) int {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	socket := discoveryEnvOr("LAN_DISCOVERY_SOCKET", "/run/localdrive-discovery/lan-discovery.sock")
	secret := sharedSecret("LAN_DISCOVERY_SHARED_SECRET")
	if len(secret) < 16 {
		log.Error("no shared secret available",
			"looked_for", "LAN_DISCOVERY_SHARED_SECRET",
			"note", "the server writes one on first start; make sure this "+
				"container can read the database directory")
		return 1
	}
	if err := os.MkdirAll(filepath.Dir(socket), 0o755); err != nil {
		log.Error("could not create the socket directory", "error", err)
		return 1
	}
	_ = os.Remove(socket)

	b := &bridge{log: log, secret: secret}

	listener, err := net.Listen("unix", socket)
	if err != nil {
		log.Error("could not listen on the socket", "socket", socket, "error", err)
		return 1
	}
	if err := os.Chmod(socket, 0o660); err != nil {
		log.Warn("could not tighten socket permissions", "error", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc(discovery.PathHealth, b.authenticated(b.handleHealth))
	mux.HandleFunc(discovery.PathAdvertise, b.authenticated(b.handleAdvertise))

	server := &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	serveErr := make(chan error, 1)
	go func() {
		log.Info("lan discovery bridge listening", "socket", socket, "version", Version)
		if err := server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	select {
	case err := <-serveErr:
		log.Error("bridge stopped", "error", err)
		b.stopAdvertising()
		_ = os.Remove(socket)
		return 1
	case <-stop:
	}
	b.stopAdvertising()
	_ = server.Close()
	_ = os.Remove(socket)
	log.Info("lan discovery bridge stopped")
	return 0
}

func (b *bridge) authenticated(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		provided := r.Header.Get(discovery.HeaderSecret)
		if subtle.ConstantTimeCompare([]byte(provided), []byte(b.secret)) != 1 {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		next(w, r)
	}
}

func (b *bridge) handleHealth(w http.ResponseWriter, r *http.Request) {
	b.mu.Lock()
	advertising := b.server != nil
	b.mu.Unlock()
	discoveryWriteJSON(w, http.StatusOK, discovery.Health{OK: true, Advertising: advertising})
}

func (b *bridge) handleAdvertise(w http.ResponseWriter, r *http.Request) {
	var ad discovery.Advertisement
	defer r.Body.Close()
	if err := json.NewDecoder(r.Body).Decode(&ad); err != nil {
		http.Error(w, "the request could not be read", http.StatusBadRequest)
		return
	}
	if err := b.apply(ad); err != nil {
		b.log.Warn("could not update the advertisement", "error", err)
		discoveryWriteJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	discoveryWriteJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// apply restarts the mDNS responder with the current name and readiness. The
// TXT records carry a name, a Version, and two booleans, never a user count or
// anything about the server's contents.
func (b *bridge) apply(ad discovery.Advertisement) error {
	b.mu.Lock()
	defer b.mu.Unlock()

	if b.current == ad && b.server != nil {
		return nil
	}
	b.current = ad

	if b.server != nil {
		_ = b.server.Shutdown()
		b.server = nil
	}
	if !ad.Enabled {
		b.log.Info("lan discovery is off, nothing is being advertised")
		return nil
	}

	port := ad.Port
	if port == 0 {
		// the bridge runs with host networking, so it knows the real port the
		// proxy published rather than guessing at 443
		if raw := discoveryEnvOr("LD_PORT", ""); raw != "" {
			if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
				port = parsed
			}
		}
	}
	if port == 0 {
		port = DefaultPort
	}
	host, err := os.Hostname()
	if err != nil {
		host = "localdrive"
	}
	name := ad.Name
	if strings.TrimSpace(name) == "" {
		name = "Local Drive"
	}

	info := []string{
		"id=" + ad.ServerID,
		"name=" + name,
		"version=" + ad.Version,
		"tls=" + strconv.FormatBool(ad.TLS),
		"ready=" + strconv.FormatBool(ad.Ready),
	}
	service, err := mdns.NewMDNSService(sanitizeInstance(name), ServiceName, "", host+".", port, nil, info)
	if err != nil {
		return fmt.Errorf("could not build the mdns service: %w", err)
	}
	server, err := mdns.NewServer(&mdns.Config{Zone: service})
	if err != nil {
		return fmt.Errorf("could not start the mdns responder: %w", err)
	}
	b.server = server
	b.log.Info("advertising on the local network", "name", name, "port", port, "ready", ad.Ready)
	return nil
}

func (b *bridge) stopAdvertising() {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.server != nil {
		_ = b.server.Shutdown()
		b.server = nil
	}
}

// sanitizeInstance keeps the advertised instance name to characters that are
// safe in a DNS label.
func sanitizeInstance(name string) string {
	var out strings.Builder
	for _, r := range name {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			out.WriteRune(r)
		case r == ' ' || r == '-' || r == '_':
			out.WriteRune('-')
		}
	}
	trimmed := strings.Trim(out.String(), "-")
	if trimmed == "" {
		return "Local-Drive"
	}
	if len(trimmed) > 63 {
		trimmed = trimmed[:63]
	}
	return trimmed
}

func discoveryWriteJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func discoveryEnvOr(key, def string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return def
}
