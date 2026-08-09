// Package discovery is the client half of the lan-discovery bridge. The main
// server never touches multicast itself; it tells the small host-networked
// binary what to advertise over the same kind of authenticated Unix socket the
// mount helper uses.
package discovery

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"time"
)

// HeaderSecret authenticates every call to the discovery bridge.
const HeaderSecret = "X-Local-Drive-Secret"

// Paths the bridge serves.
const (
	PathAdvertise = "/v1/advertise"
	PathHealth    = "/v1/health"
)

// ErrUnavailable means no bridge is configured or it is not answering.
var ErrUnavailable = errors.New("discovery: the lan discovery bridge is not available")

// Advertisement is what the bridge announces over mDNS. Deliberately nothing
// about users, files, or contents.
type Advertisement struct {
	Enabled  bool   `json:"enabled"`
	ServerID string `json:"id"`
	Name     string `json:"name"`
	Version  string `json:"version"`
	Port     int    `json:"port"`
	TLS      bool   `json:"tls"`
	Ready    bool   `json:"ready"`
}

// Health is the bridge's own readiness.
type Health struct {
	OK          bool `json:"ok"`
	Advertising bool `json:"advertising"`
}

// Client talks to the bridge.
type Client struct {
	http    *http.Client
	secret  string
	enabled bool
}

// NewClient returns a client, disabled when no socket is configured.
func NewClient(socketPath, secret string) *Client {
	if socketPath == "" || secret == "" {
		return &Client{enabled: false}
	}
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	return &Client{
		enabled: true,
		secret:  secret,
		http: &http.Client{
			Timeout: 10 * time.Second,
			Transport: &http.Transport{
				DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
					return dialer.DialContext(ctx, "unix", socketPath)
				},
				MaxIdleConns:    1,
				IdleConnTimeout: 30 * time.Second,
			},
		},
	}
}

// Enabled reports whether a bridge is configured at all.
func (c *Client) Enabled() bool { return c.enabled }

// Advertise pushes the current name and ready state to the bridge.
func (c *Client) Advertise(ctx context.Context, ad Advertisement) error {
	if !c.enabled {
		return ErrUnavailable
	}
	var buf bytes.Buffer
	if err := json.NewEncoder(&buf).Encode(ad); err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://discovery"+PathAdvertise, &buf)
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set(HeaderSecret, c.secret)
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrUnavailable, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return fmt.Errorf("discovery: bridge returned %s", resp.Status)
	}
	return nil
}
