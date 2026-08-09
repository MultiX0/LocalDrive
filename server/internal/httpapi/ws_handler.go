package httpapi

import (
	"context"
	"fmt"
	"net/http"
	"runtime"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/db"
	"github.com/MultiX0/LocalDrive/server/internal/discovery"
	mw "github.com/MultiX0/LocalDrive/server/internal/middleware"
	"github.com/MultiX0/LocalDrive/server/internal/ws"
)

func (a *API) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	user, ok := mw.UserFrom(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized", "sign in first")
		return
	}
	sessionID := mw.SessionFrom(r.Context())
	client := a.hub.Register(db.NewID(), user.ID, sessionID)
	if client == nil {
		writeError(w, http.StatusServiceUnavailable, "shutting_down", "the server is restarting")
		return
	}
	ws.Serve(w, r, a.hub, client, a.cfg.CORSAllowedOrigins, a.log)
}

// refreshDiscovery pushes the current name and readiness to the lan-discovery
// bridge. Failure is never fatal; discovery is a convenience.
func (a *API) refreshDiscovery(ctx context.Context) {
	if a.discovery == nil || !a.discovery.Enabled() {
		return
	}
	cfg := a.settings.Get()
	ready := false
	if list, err := a.libs.List(ctx); err == nil {
		for _, lib := range list {
			if lib.Online() {
				ready = true
				break
			}
		}
	}
	err := a.discovery.Advertise(ctx, discovery.Advertisement{
		Enabled:  cfg.EnableLANDiscovery,
		ServerID: cfg.ServerID,
		Name:     cfg.ServerName,
		Version:  Version,
		Ready:    ready,
	})
	if err != nil {
		a.log.Debug("lan discovery update failed", "error", err)
	}
}

// handleMetrics writes the Prometheus text format by hand, which is cheaper
// than pulling in the client library for the handful of numbers worth having.
func (a *API) handleMetrics(w http.ResponseWriter, r *http.Request) {
	var mem runtime.MemStats
	runtime.ReadMemStats(&mem)
	submitted, completed, failed, dropped, queued := a.pool.Stats()

	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	metric := func(name, help, kind string, value any) {
		fmt.Fprintf(w, "# HELP %s %s\n# TYPE %s %s\n%s %v\n", name, help, name, kind, name, value)
	}
	metric("localdrive_uptime_seconds", "Seconds since the server started", "gauge",
		int64(time.Since(a.startedAt).Seconds()))
	metric("localdrive_goroutines", "Live goroutines", "gauge", runtime.NumGoroutine())
	metric("localdrive_memory_heap_bytes", "Heap in use", "gauge", mem.HeapInuse)
	metric("localdrive_memory_sys_bytes", "Memory obtained from the OS", "gauge", mem.Sys)
	metric("localdrive_websocket_connections", "Live websocket connections", "gauge",
		a.hub.Connections())
	metric("localdrive_jobs_submitted_total", "Background jobs submitted", "counter", submitted)
	metric("localdrive_jobs_completed_total", "Background jobs completed", "counter", completed)
	metric("localdrive_jobs_failed_total", "Background jobs failed", "counter", failed)
	metric("localdrive_jobs_dropped_total", "Background jobs dropped because the queue was full", "counter", dropped)
	metric("localdrive_jobs_queued", "Background jobs waiting", "gauge", queued)

	if list, err := a.libs.List(r.Context()); err == nil {
		for _, lib := range list {
			online := 0
			if lib.Online() {
				online = 1
			}
			fmt.Fprintf(w, "localdrive_library_online{library=%q} %d\n", lib.Name, online)
			fmt.Fprintf(w, "localdrive_library_bytes_used{library=%q} %d\n", lib.Name, lib.BytesUsed)
			if lib.StatsKnown {
				fmt.Fprintf(w, "localdrive_library_bytes_free{library=%q} %d\n", lib.Name, lib.FreeBytes)
				fmt.Fprintf(w, "localdrive_library_bytes_total{library=%q} %d\n", lib.Name, lib.TotalBytes)
			}
		}
	}
}
