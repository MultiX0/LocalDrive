package runner

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"io"
	"math/big"
	"net"
	"net/http"
	"strings"
	"testing"
	"time"
)

// One port has to answer both protocols, because a server with a domain holds
// a certificate for that name alone: https to its ip address is refused during
// the handshake, and without plain http there would be no way in from the same
// network at all.
func TestOnePortAnswersHttpsAndPlainHTTP(t *testing.T) {
	ln, handler := muxedServer(t)

	t.Run("https", func(t *testing.T) {
		client := &http.Client{Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // #nosec G402
		}}
		body, status := get(t, client, "https://"+ln.Addr().String()+"/healthz")
		if status != http.StatusOK || body != "served" {
			t.Fatalf("https got %d %q, want 200 \"served\"", status, body)
		}
	})

	t.Run("plain http", func(t *testing.T) {
		body, status := get(t, http.DefaultClient, "http://"+ln.Addr().String()+"/healthz")
		if status != http.StatusOK || body != "served" {
			t.Fatalf("plain http got %d %q, want 200 \"served\"", status, body)
		}
	})

	if handler.hits != 2 {
		t.Fatalf("the handler saw %d requests, want 2", handler.hits)
	}
}

// A connection that opens and then says nothing must not stop the listener
// accepting anyone else. Classifying a connection means reading from it, so
// doing that on the accept goroutine would let one silent client take the
// whole server down.
func TestASilentConnectionDoesNotBlockTheListener(t *testing.T) {
	ln, _ := muxedServer(t)

	silent, err := net.Dial("tcp", ln.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer silent.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		body, status := get(t, http.DefaultClient, "http://"+ln.Addr().String()+"/healthz")
		if status != http.StatusOK || body != "served" {
			t.Errorf("got %d %q while another connection was silent", status, body)
		}
	}()

	select {
	case <-done:
	case <-time.After(10 * time.Second):
		t.Fatal("a silent connection blocked the listener")
	}
}

// The first byte is read to decide the protocol and has to be handed back, or
// every request would arrive with its method truncated.
func TestTheSniffedByteIsNotSwallowed(t *testing.T) {
	ln, handler := muxedServer(t)

	body, status := get(t, http.DefaultClient, "http://"+ln.Addr().String()+"/deep/path?q=1")
	if status != http.StatusOK || body != "served" {
		t.Fatalf("got %d %q", status, body)
	}
	if handler.method != http.MethodGet || handler.path != "/deep/path" {
		t.Fatalf("the handler saw %q %q, want GET /deep/path", handler.method, handler.path)
	}
	if handler.query != "q=1" {
		t.Fatalf("the handler saw query %q, want q=1", handler.query)
	}
}

// guard decides what happens to a request that arrives in the clear. Serving
// the lan is the whole point of the shared port; carrying a password across
// the internet in plain text when a working name exists is not.
func TestGuardServesTheLANAndRedirectsEverythingElse(t *testing.T) {
	auto := &autoTLS{domain: "drive.example.com", port: 7443}
	served := false
	handler := auto.guard(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		served = true
		w.WriteHeader(http.StatusOK)
	}))

	cases := []struct {
		name     string
		remote   string
		host     string
		tls      bool
		wantPass bool
		wantTo   string
	}{
		{
			name:     "https under the domain is the normal case",
			remote:   "203.0.113.9:5000",
			host:     "drive.example.com:7443",
			tls:      true,
			wantPass: true,
		},
		{
			name:     "a phone on the same wifi has no certificate available",
			remote:   "192.168.1.44:5000",
			host:     "192.168.1.10:7443",
			wantPass: true,
		},
		{
			name:     "loopback is how the health probe asks",
			remote:   "127.0.0.1:5000",
			host:     "127.0.0.1:7443",
			wantPass: true,
		},
		{
			name:   "the domain in the clear had https available and skipped it",
			remote: "192.168.1.44:5000",
			host:   "drive.example.com:7443",
			wantTo: "https://drive.example.com:7443/api/v1/me",
		},
		{
			name:   "the public internet gets sent to the name that works",
			remote: "203.0.113.9:5000",
			host:   "198.51.100.7:7443",
			wantTo: "https://drive.example.com:7443/api/v1/me",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			served = false
			req := httpRequest(tc.remote, tc.host, tc.tls, 7443)
			rec := &recorder{header: http.Header{}}
			handler.ServeHTTP(rec, req)

			if tc.wantPass {
				if !served {
					t.Fatalf("the request was turned away with %d, want it served", rec.status)
				}
				return
			}
			if served {
				t.Fatal("the request reached the application in the clear")
			}
			if got := rec.header.Get("Location"); got != tc.wantTo {
				t.Fatalf("redirected to %q, want %q", got, tc.wantTo)
			}
		})
	}
}

// 443 may not be bindable without privileges, so a redirect that drops the
// port would send people to a socket with nothing on it.
func TestTheRedirectKeepsThePortTheRequestArrivedOn(t *testing.T) {
	auto := &autoTLS{domain: "drive.example.com", port: 9000}
	handler := auto.guard(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("a public plain http request should not be served")
	}))

	rec := &recorder{header: http.Header{}}
	handler.ServeHTTP(rec, httpRequest("203.0.113.9:5000", "198.51.100.7:9000", false, 9000))

	if got := rec.header.Get("Location"); got != "https://drive.example.com:9000/api/v1/me" {
		t.Fatalf("redirected to %q", got)
	}
}

func muxedServer(t *testing.T) (net.Listener, *spyHandler) {
	t.Helper()

	inner, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	ln := serveBothProtocols(inner, &tls.Config{
		Certificates: []tls.Certificate{selfSigned(t)},
		MinVersion:   tls.VersionTLS12,
	})

	handler := &spyHandler{}
	srv := &http.Server{Handler: handler, ReadHeaderTimeout: 5 * time.Second}
	go func() { _ = srv.Serve(ln) }()
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = srv.Shutdown(ctx)
	})
	return ln, handler
}

type spyHandler struct {
	hits   int
	method string
	path   string
	query  string
}

func (s *spyHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	s.hits++
	s.method, s.path, s.query = r.Method, r.URL.Path, r.URL.RawQuery
	_, _ = io.WriteString(w, "served")
}

type recorder struct {
	header http.Header
	status int
}

func (r *recorder) Header() http.Header         { return r.header }
func (r *recorder) Write(b []byte) (int, error) { return len(b), nil }
func (r *recorder) WriteHeader(status int)      { r.status = status }

func httpRequest(remote, host string, overTLS bool, port int) *http.Request {
	req, _ := http.NewRequest(http.MethodGet, "http://"+host+"/api/v1/me", nil)
	req.RemoteAddr = remote
	req.Host = host
	if overTLS {
		req.TLS = &tls.ConnectionState{}
	}
	ctx := context.WithValue(req.Context(), http.LocalAddrContextKey,
		&net.TCPAddr{IP: net.IPv4zero, Port: port})
	return req.WithContext(ctx)
}

func get(t *testing.T, client *http.Client, url string) (string, int) {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		t.Fatal(err)
	}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("%s: %v", url, err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	return strings.TrimSpace(string(body)), resp.StatusCode
}

func selfSigned(t *testing.T) tls.Certificate {
	t.Helper()

	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	template := x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "localhost"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
	}
	der, err := x509.CreateCertificate(rand.Reader, &template, &template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	return tls.Certificate{Certificate: [][]byte{der}, PrivateKey: key}
}
