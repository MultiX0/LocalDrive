package discovery

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net"
	"strings"
	"sync"
	"time"
)

// The beacon is a plain UDP question and answer, and it exists because mDNS
// cannot be relied on.
//
// On Windows the operating system runs its own mDNS responder holding UDP
// 5353. A second process can bind the port and even report success, but the
// queries are delivered to the OS responder, which knows nothing about this
// service, so the record is published and never answered. From the app it
// looks exactly like no server on the network. Docker adds its own version of
// the same problem, since a container cannot put multicast on the real LAN
// without host networking.
//
// So: the client broadcasts one small packet, and any server that hears it
// replies with how to reach it. No multicast group, no responder to compete
// with, and it behaves the same on a wired network, a wifi network and a
// phone's hotspot.
const (
	// BeaconPort is deliberately the same number as the default http port, one
	// being udp and the other tcp, so there is one number to remember and one
	// firewall rule to allow.
	BeaconPort = 7443

	probeMagic = "LOCALDRIVE-PROBE/1"
	replyMagic = "LOCALDRIVE-HELLO/1"

	// a reply is a few hundred bytes; this is generous and still far below the
	// point where a udp datagram would fragment
	maxPacket = 2048
)

// BeaconReply is what a server sends back to a probe.
//
// Only what the app needs to show a row and connect to it. No user count, no
// file count, nothing about what the server holds: this answers anybody on the
// network who asks, including devices with no account here.
type BeaconReply struct {
	Magic    string `json:"magic"`
	ServerID string `json:"server_id"`
	Name     string `json:"name"`
	Version  string `json:"version"`
	Port     int    `json:"port"`
	TLS      bool   `json:"tls"`
	Ready    bool   `json:"ready"`
}

// Beacon answers discovery probes over UDP.
type Beacon struct {
	log  *slog.Logger
	port int

	mu      sync.RWMutex
	current Advertisement
	conn    *net.UDPConn
	stopped bool
}

// NewBeacon builds a beacon. Nothing listens until Start.
func NewBeacon(log *slog.Logger, port int) *Beacon {
	if port <= 0 {
		port = BeaconPort
	}
	return &Beacon{log: log, port: port}
}

// Start begins listening. A failure here is logged and not returned as fatal:
// discovery is a convenience, and a server that cannot advertise still serves
// every client that is given its address.
func (b *Beacon) Start() {
	conn, err := net.ListenUDP("udp4", &net.UDPAddr{IP: net.IPv4zero, Port: b.port})
	if err != nil {
		b.log.Warn("discovery beacon could not listen, the apps will need the address typed in",
			"port", b.port, "error", err)
		return
	}

	b.mu.Lock()
	b.conn = conn
	b.mu.Unlock()

	go b.serve(conn)
	b.log.Info("discovery beacon listening", "port", b.port)
}

func (b *Beacon) serve(conn *net.UDPConn) {
	buf := make([]byte, maxPacket)
	for {
		n, from, err := conn.ReadFromUDP(buf)
		if err != nil {
			b.mu.RLock()
			stopped := b.stopped
			b.mu.RUnlock()
			if stopped || errors.Is(err, net.ErrClosed) {
				return
			}
			b.log.Debug("discovery beacon read failed", "error", err)
			continue
		}

		if !strings.HasPrefix(strings.TrimSpace(string(buf[:n])), probeMagic) {
			// something else on the port; ignore it rather than answering
			continue
		}

		b.mu.RLock()
		ad := b.current
		b.mu.RUnlock()

		// an admin who turned discovery off means it, so stay silent
		if !ad.Enabled {
			continue
		}

		port := ad.Port
		if port == 0 {
			port = b.port
		}
		name := strings.TrimSpace(ad.Name)
		if name == "" {
			name = "Local Drive"
		}

		payload, err := json.Marshal(BeaconReply{
			Magic:    replyMagic,
			ServerID: ad.ServerID,
			Name:     name,
			Version:  ad.Version,
			Port:     port,
			TLS:      ad.TLS,
			Ready:    ad.Ready,
		})
		if err != nil {
			continue
		}

		_ = conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
		if _, err := conn.WriteToUDP(payload, from); err != nil {
			b.log.Debug("discovery reply failed", "to", from.String(), "error", err)
		}
	}
}

// Advertise updates what the beacon answers with.
func (b *Beacon) Advertise(ad Advertisement) {
	b.mu.Lock()
	b.current = ad
	b.mu.Unlock()
}

// Stop closes the socket.
func (b *Beacon) Stop() {
	b.mu.Lock()
	b.stopped = true
	conn := b.conn
	b.conn = nil
	b.mu.Unlock()
	if conn != nil {
		_ = conn.Close()
	}
}
