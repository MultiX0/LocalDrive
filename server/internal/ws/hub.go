package ws

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"
)

// outboundBuffer is how many messages one client may fall behind by before
// the hub starts dropping its oldest queued message.
const outboundBuffer = 64

// Client is one live connection.
type Client struct {
	ID        string
	UserID    string
	SessionID string
	send      chan []byte
	closeOnce sync.Once
	closed    chan struct{}
	dropped   int64
}

// Send returns the outbound queue the writer goroutine drains.
func (c *Client) Send() <-chan []byte { return c.send }

// Done is closed when the hub has unregistered this client.
func (c *Client) Done() <-chan struct{} { return c.closed }

func (c *Client) close() {
	c.closeOnce.Do(func() {
		close(c.closed)
		close(c.send)
	})
}

// Hub owns registration and fan-out. All state lives on one goroutine.
type Hub struct {
	register   chan *Client
	unregister chan *Client
	broadcast  chan envelope
	clients    map[string]map[*Client]struct{} // by user id
	log        *slog.Logger
	stop       chan struct{}
	stopped    chan struct{}
	countMu    sync.RWMutex
	count      int
}

type envelope struct {
	userIDs []string
	data    []byte
}

// NewHub returns a started hub.
func NewHub(log *slog.Logger) *Hub {
	if log == nil {
		log = slog.Default()
	}
	h := &Hub{
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan envelope, 256),
		clients:    map[string]map[*Client]struct{}{},
		log:        log,
		stop:       make(chan struct{}),
		stopped:    make(chan struct{}),
	}
	go h.run()
	return h
}

func (h *Hub) run() {
	defer close(h.stopped)
	for {
		select {
		case <-h.stop:
			for _, set := range h.clients {
				for c := range set {
					c.close()
				}
			}
			h.clients = map[string]map[*Client]struct{}{}
			h.setCount(0)
			return

		case c := <-h.register:
			set, ok := h.clients[c.UserID]
			if !ok {
				set = map[*Client]struct{}{}
				h.clients[c.UserID] = set
			}
			set[c] = struct{}{}
			h.setCount(h.total())

		case c := <-h.unregister:
			if set, ok := h.clients[c.UserID]; ok {
				if _, present := set[c]; present {
					delete(set, c)
					c.close()
				}
				if len(set) == 0 {
					delete(h.clients, c.UserID)
				}
			}
			h.setCount(h.total())

		case env := <-h.broadcast:
			for _, uid := range env.userIDs {
				for c := range h.clients[uid] {
					h.deliver(c, env.data)
				}
			}
		}
	}
}

// deliver never blocks. A client that is not draining loses its oldest queued
// message rather than holding up every other client on the server.
func (h *Hub) deliver(c *Client, data []byte) {
	select {
	case c.send <- data:
		return
	default:
	}
	select {
	case <-c.send:
		c.dropped++
	default:
	}
	select {
	case c.send <- data:
	default:
		c.dropped++
	}
}

func (h *Hub) total() int {
	n := 0
	for _, set := range h.clients {
		n += len(set)
	}
	return n
}

func (h *Hub) setCount(n int) {
	h.countMu.Lock()
	h.count = n
	h.countMu.Unlock()
}

// Connections reports how many clients are live, for /metrics.
func (h *Hub) Connections() int {
	h.countMu.RLock()
	defer h.countMu.RUnlock()
	return h.count
}

// Register adds a client and returns it, or nil once the hub has stopped.
func (h *Hub) Register(id, userID, sessionID string) *Client {
	c := &Client{
		ID:        id,
		UserID:    userID,
		SessionID: sessionID,
		send:      make(chan []byte, outboundBuffer),
		closed:    make(chan struct{}),
	}
	select {
	case h.register <- c:
		return c
	case <-h.stop:
		return nil
	}
}

// Unregister removes a client. Safe to call more than once.
func (h *Hub) Unregister(c *Client) {
	if c == nil {
		return
	}
	select {
	case h.unregister <- c:
	case <-h.stop:
	case <-time.After(2 * time.Second):
		h.log.Warn("hub unregister timed out", "client", c.ID)
	}
}

// Publish sends an event to every listed user. Duplicate ids are fine.
func (h *Hub) Publish(event Event, userIDs ...string) {
	if len(userIDs) == 0 {
		return
	}
	data, err := json.Marshal(event)
	if err != nil {
		h.log.Error("event marshal failed", "type", event.Type, "error", err)
		return
	}
	unique := make([]string, 0, len(userIDs))
	seen := map[string]struct{}{}
	for _, id := range userIDs {
		if id == "" {
			continue
		}
		if _, dup := seen[id]; dup {
			continue
		}
		seen[id] = struct{}{}
		unique = append(unique, id)
	}
	if len(unique) == 0 {
		return
	}
	select {
	case h.broadcast <- envelope{userIDs: unique, data: data}:
	case <-h.stop:
	default:
		// the hub itself is saturated, which only happens under extreme load;
		// shedding a live-update event is the right thing to lose here
		h.log.Warn("hub broadcast queue full, event dropped", "type", event.Type)
	}
}

// Close shuts the hub down and disconnects every client.
func (h *Hub) Close(ctx context.Context) error {
	select {
	case <-h.stop:
		return nil
	default:
	}
	close(h.stop)
	select {
	case <-h.stopped:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
