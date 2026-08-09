package middleware

import (
	"net/http"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// Limiter is a token-bucket limiter keyed by an arbitrary string, with a
// janitor that drops idle buckets so the map cannot grow without bound.
type Limiter struct {
	mu       sync.Mutex
	buckets  map[string]*bucket
	rate     rate.Limit
	burst    int
	idleFor  time.Duration
	stopOnce sync.Once
	stop     chan struct{}
}

type bucket struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// NewLimiter returns a limiter allowing perSecond requests with the given
// burst, forgetting a key after it goes quiet.
func NewLimiter(perSecond float64, burst int) *Limiter {
	l := &Limiter{
		buckets: map[string]*bucket{},
		rate:    rate.Limit(perSecond),
		burst:   burst,
		idleFor: 10 * time.Minute,
		stop:    make(chan struct{}),
	}
	go l.janitor()
	return l
}

func (l *Limiter) janitor() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			cutoff := time.Now().Add(-l.idleFor)
			l.mu.Lock()
			for key, b := range l.buckets {
				if b.lastSeen.Before(cutoff) {
					delete(l.buckets, key)
				}
			}
			l.mu.Unlock()
		case <-l.stop:
			return
		}
	}
}

// Allow reports whether one request may proceed for this key.
func (l *Limiter) Allow(key string) bool {
	l.mu.Lock()
	b, ok := l.buckets[key]
	if !ok {
		b = &bucket{limiter: rate.NewLimiter(l.rate, l.burst)}
		l.buckets[key] = b
	}
	b.lastSeen = time.Now()
	l.mu.Unlock()
	return b.limiter.Allow()
}

// Close stops the janitor.
func (l *Limiter) Close() {
	l.stopOnce.Do(func() { close(l.stop) })
}

// KeyFunc picks the bucket key for one request.
type KeyFunc func(r *http.Request) string

// ByIP keys a limiter on the resolved client address, for auth endpoints.
func ByIP(r *http.Request) string {
	return "ip:" + ClientIPFrom(r.Context())
}

// ByUser keys a limiter on the account, falling back to the address for
// unauthenticated calls, for the general API.
func ByUser(r *http.Request) string {
	if id, ok := UserIDFrom(r.Context()); ok {
		return "user:" + id
	}
	return "ip:" + ClientIPFrom(r.Context())
}

// RateLimit rejects a request whose bucket is empty with a 429 and a
// Retry-After the client can actually use.
func RateLimit(limiter *Limiter, key KeyFunc) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if !limiter.Allow(key(r)) {
				w.Header().Set("Retry-After", "1")
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				_, _ = w.Write([]byte(`{"error":{"code":"rate_limited","message":"too many requests, slow down"}}`))
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

// Semaphore bounds how many requests one key may have in flight at once, which
// is how a single client is kept from exhausting file descriptors during a
// bulk upload.
type Semaphore struct {
	mu       sync.Mutex
	inFlight map[string]int
	limit    int
}

// NewSemaphore returns a per-key concurrency limiter.
func NewSemaphore(limit int) *Semaphore {
	if limit <= 0 {
		limit = 4
	}
	return &Semaphore{inFlight: map[string]int{}, limit: limit}
}

// Acquire takes a slot, reporting whether one was available.
func (s *Semaphore) Acquire(key string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.inFlight[key] >= s.limit {
		return false
	}
	s.inFlight[key]++
	return true
}

// Release gives a slot back.
func (s *Semaphore) Release(key string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.inFlight[key] <= 1 {
		delete(s.inFlight, key)
		return
	}
	s.inFlight[key]--
}

// LimitConcurrency wraps a handler in a per-key in-flight cap.
func LimitConcurrency(sem *Semaphore, key KeyFunc) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			k := key(r)
			if !sem.Acquire(k) {
				w.Header().Set("Retry-After", "2")
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusTooManyRequests)
				_, _ = w.Write([]byte(`{"error":{"code":"too_many_uploads","message":"too many transfers at once, the rest are queued"}}`))
				return
			}
			defer sem.Release(k)
			next.ServeHTTP(w, r)
		})
	}
}
