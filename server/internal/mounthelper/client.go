package mounthelper

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

// ErrUnavailable means no helper is configured or it is not answering. Every
// caller treats that as "drive management is not available on this
// deployment", never as a hard failure of the request that asked.
var ErrUnavailable = errors.New("mounthelper: the drive helper is not available")

// Client talks to the helper over its Unix socket.
type Client struct {
	http    *http.Client
	secret  string
	enabled bool
}

// NewClient returns a client, disabled when no socket path is configured.
func NewClient(socketPath, secret string) *Client {
	if socketPath == "" || secret == "" {
		return &Client{enabled: false}
	}
	dialer := &net.Dialer{Timeout: 5 * time.Second}
	return &Client{
		enabled: true,
		secret:  secret,
		http: &http.Client{
			Timeout: 120 * time.Second,
			Transport: &http.Transport{
				DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
					return dialer.DialContext(ctx, "unix", socketPath)
				},
				MaxIdleConns:    2,
				IdleConnTimeout: 30 * time.Second,
			},
		},
	}
}

// Enabled reports whether a helper is configured at all.
func (c *Client) Enabled() bool { return c.enabled }

// List returns every detected block device.
func (c *Client) List(ctx context.Context) ([]Drive, error) {
	var out ListResponse
	if err := c.call(ctx, PathList, nil, &out); err != nil {
		return nil, err
	}
	return out.Drives, nil
}

// Mount attaches one device under the external mounts directory.
func (c *Client) Mount(ctx context.Context, req MountRequest) (MountResponse, error) {
	var out MountResponse
	err := c.call(ctx, PathMount, req, &out)
	return out, err
}

// Unmount releases one mount point cleanly.
func (c *Client) Unmount(ctx context.Context, mountPoint string) error {
	return c.call(ctx, PathUnmount, UnmountRequest{MountPoint: mountPoint}, nil)
}

// Format erases a device. The confirmation phrase is checked on both sides.
func (c *Client) Format(ctx context.Context, req FormatRequest) error {
	if req.Confirmation != FormatConfirmation {
		return fmt.Errorf("mounthelper: the confirmation phrase does not match")
	}
	return c.call(ctx, PathFormat, req, nil)
}

// Pool combines mounted drives into one union mount.
func (c *Client) Pool(ctx context.Context, req PoolRequest) (PoolResponse, error) {
	var out PoolResponse
	err := c.call(ctx, PathPool, req, &out)
	return out, err
}

func (c *Client) call(ctx context.Context, path string, body, out any) error {
	if !c.enabled {
		return ErrUnavailable
	}
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			return err
		}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "http://helper"+path, &buf)
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
		var e ErrorResponse
		_ = json.NewDecoder(resp.Body).Decode(&e)
		if e.Error == "" {
			e.Error = resp.Status
		}
		return fmt.Errorf("mounthelper: %s", e.Error)
	}
	if out == nil {
		return nil
	}
	return json.NewDecoder(resp.Body).Decode(out)
}
