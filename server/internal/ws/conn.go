package ws

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"nhooyr.io/websocket"
)

const (
	pingInterval = 30 * time.Second
	writeTimeout = 10 * time.Second
	// clients send nothing but pongs and an occasional ping, so anything
	// larger than this is a client bug or an attempt to waste memory
	maxReadBytes = 4 * 1024
)

// Serve upgrades one request and pumps the client's outbound queue until it
// disconnects or the hub shuts it down.
func Serve(w http.ResponseWriter, r *http.Request, hub *Hub, client *Client, allowedOrigins []string, log *slog.Logger) {
	if log == nil {
		log = slog.Default()
	}
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns:  originPatterns(allowedOrigins),
		CompressionMode: websocket.CompressionDisabled,
	})
	if err != nil {
		hub.Unregister(client)
		log.Debug("websocket accept failed", "error", err)
		return
	}
	conn.SetReadLimit(maxReadBytes)

	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()

	// a reader is required so control frames are processed; the protocol is
	// server to client only, so anything a client sends is ignored
	go func() {
		defer cancel()
		for {
			if _, _, err := conn.Read(ctx); err != nil {
				return
			}
		}
	}()

	ticker := time.NewTicker(pingInterval)
	defer ticker.Stop()
	defer hub.Unregister(client)

	for {
		select {
		case <-ctx.Done():
			conn.Close(websocket.StatusNormalClosure, "")
			return

		case <-client.Done():
			conn.Close(websocket.StatusNormalClosure, "server closing")
			return

		case msg, ok := <-client.Send():
			if !ok {
				conn.Close(websocket.StatusNormalClosure, "server closing")
				return
			}
			writeCtx, writeCancel := context.WithTimeout(ctx, writeTimeout)
			err := conn.Write(writeCtx, websocket.MessageText, msg)
			writeCancel()
			if err != nil {
				if !errors.Is(err, context.Canceled) {
					log.Debug("websocket write failed", "error", err)
				}
				conn.Close(websocket.StatusInternalError, "write failed")
				return
			}

		case <-ticker.C:
			pingCtx, pingCancel := context.WithTimeout(ctx, writeTimeout)
			err := conn.Ping(pingCtx)
			pingCancel()
			if err != nil {
				conn.Close(websocket.StatusPolicyViolation, "ping timeout")
				return
			}
		}
	}
}

// originPatterns keeps the websocket handshake as restricted as CORS is. An
// empty list means same-origin only, which is what nhooyr does by default.
func originPatterns(allowed []string) []string {
	out := make([]string, 0, len(allowed))
	for _, origin := range allowed {
		host := origin
		for _, prefix := range []string{"https://", "http://"} {
			if len(host) > len(prefix) && host[:len(prefix)] == prefix {
				host = host[len(prefix):]
				break
			}
		}
		if host != "" {
			out = append(out, host)
		}
	}
	return out
}
