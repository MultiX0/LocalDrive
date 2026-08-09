package discovery

import (
	"context"
	"log/slog"
	"os"
	"strings"
	"sync"

	"github.com/hashicorp/mdns"
)

// Announcer is whatever puts this server on the network so the apps can find
// it without being told an address.
//
// Two implementations, picked by how the server is running. Under Docker the
// server has its own network namespace and cannot send multicast onto the real
// LAN, so it hands advertisements to a helper container over a unix socket.
// Running directly there is no namespace in the way, and a helper would be a
// second process for no reason: the server announces itself.
type Announcer interface {
	Enabled() bool
	Advertise(ctx context.Context, ad Advertisement) error
}

// ServiceName is what a client browses for during onboarding.
const ServiceName = "_localdrive._tcp"

// LocalAnnouncer advertises the server from inside the server process.
//
// It publishes both an mDNS record and a UDP beacon, because neither is
// sufficient alone. mDNS is what other software already speaks, so it is worth
// having where it works; it does not work when the host runs its own responder
// on 5353, which Windows does. The beacon has no such competition and is the
// one that actually answers on every platform. Publishing both costs one extra
// socket and means the app finds the server whichever mechanism succeeds.
type LocalAnnouncer struct {
	log         *slog.Logger
	defaultPort int
	beacon      *Beacon

	mu      sync.Mutex
	server  *mdns.Server
	current Advertisement
}

// NewLocalAnnouncer builds an announcer for a server running directly on a
// machine, where its own network is the one the phones are on.
func NewLocalAnnouncer(log *slog.Logger, defaultPort int) *LocalAnnouncer {
	a := &LocalAnnouncer{
		log:         log,
		defaultPort: defaultPort,
		beacon:      NewBeacon(log, defaultPort),
	}
	a.beacon.Start()
	return a
}

func (a *LocalAnnouncer) Enabled() bool { return true }

// Advertise republishes the record whenever the name or readiness changes.
//
// The TXT records carry an id, a name, a version and two booleans. Never a
// user count, never anything about what the server holds: this goes to every
// device on the network, including ones with no account here.
func (a *LocalAnnouncer) Advertise(ctx context.Context, ad Advertisement) error {
	// the beacon holds the answer rather than a live socket per change, so it
	// is updated first and unconditionally
	if ad.Port == 0 {
		ad.Port = a.defaultPort
	}
	a.beacon.Advertise(ad)

	a.mu.Lock()
	defer a.mu.Unlock()

	if a.current == ad && a.server != nil {
		return nil
	}
	a.current = ad

	if a.server != nil {
		_ = a.server.Shutdown()
		a.server = nil
	}
	if !ad.Enabled {
		a.log.Info("lan discovery is off, nothing is being advertised")
		return nil
	}

	port := ad.Port
	if port == 0 {
		port = a.defaultPort
	}

	host, err := os.Hostname()
	if err != nil || strings.TrimSpace(host) == "" {
		host = "localdrive"
	}
	name := strings.TrimSpace(ad.Name)
	if name == "" {
		name = "Local Drive"
	}

	// The instance is the friendly name people see, and the host has to be a
	// fully qualified name with the trailing dot. Passing the machine name as
	// the instance and leaving the host empty builds a record that no client
	// resolves, which looks exactly like nothing advertising at all.
	service, err := mdns.NewMDNSService(
		sanitizeInstance(name),
		ServiceName,
		"",
		host+".",
		port,
		nil,
		[]string{
			"id=" + ad.ServerID,
			"name=" + name,
			"version=" + ad.Version,
			"tls=" + boolText(ad.TLS),
			"ready=" + boolText(ad.Ready),
		},
	)
	if err != nil {
		return err
	}

	server, err := mdns.NewServer(&mdns.Config{Zone: service})
	if err != nil {
		return err
	}
	a.server = server
	a.log.Info("advertising on the local network",
		"service", ServiceName, "host", host, "port", port, "name", name)
	return nil
}

// Stop withdraws the record, so a stopped server does not linger in the app's
// discovery list until the record expires on its own.
func (a *LocalAnnouncer) Stop() {
	a.beacon.Stop()
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.server != nil {
		_ = a.server.Shutdown()
		a.server = nil
	}
}

// sanitizeInstance reduces a server name to what a DNS-SD instance label
// allows. A name someone typed can hold anything, and an invalid label makes
// the responder refuse to start rather than advertise something imperfect.
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

func boolText(v bool) string {
	if v {
		return "true"
	}
	return "false"
}
