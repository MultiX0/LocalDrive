package runner

import (
	"crypto/tls"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/MultiX0/LocalDrive/server/internal/config"
)

// The built in certificate is opt in, and the thing that opts in is a domain.
// Every install without one has to behave exactly as it did before automatic
// https existed: no acme client, no second listener, no port 80.
func TestAutoTLSIsOffUnlessADomainAsksForIt(t *testing.T) {
	cases := []struct {
		name   string
		domain string
		mode   string
		want   bool
	}{
		{"no domain at all", "", "auto", false},
		{"no domain, mode set anyway", "", "on", false},
		{"whitespace is not a domain", "   ", "auto", false},
		{"a domain", "drive.example.com", "auto", true},
		{"a domain, mode empty", "drive.example.com", "", true},
		{"turned off by hand", "drive.example.com", "off", false},
		{"off, as compose pins it", "drive.example.com", "off", false},
		{"an ipv4 is not signable", "192.168.1.10", "auto", false},
		{"an ipv6 is not signable", "fe80::1", "auto", false},
		{"a bare hostname is not signable", "localhost", "auto", false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := &config.Config{TLSDomain: tc.domain, TLSMode: tc.mode}
			if got := wantsAutoTLS(cfg); got != tc.want {
				t.Fatalf("wantsAutoTLS(domain=%q mode=%q) = %v, want %v",
					tc.domain, tc.mode, got, tc.want)
			}
		})
	}
}

// maybeAutoTLS has to return a nil manager rather than an error when there is
// no domain, since serve treats an error as fatal.
func TestNoDomainReturnsNoManagerAndNoError(t *testing.T) {
	auto, err := maybeAutoTLS(&config.Config{})
	if err != nil {
		t.Fatalf("expected no error for an install with no domain, got %v", err)
	}
	if auto != nil {
		t.Fatal("expected no certificate manager for an install with no domain")
	}
}

func TestPortOf(t *testing.T) {
	cases := map[string]string{
		":7443":          "7443",
		"0.0.0.0:7443":   "7443",
		"127.0.0.1:8080": "8080",
		"":               "",
	}
	for in, want := range cases {
		if got := portOf(in); got != want {
			t.Fatalf("portOf(%q) = %q, want %q", in, got, want)
		}
	}
}

// A domain whose challenge cannot be reached takes the whole server down
// without stopping it: the process runs, the port accepts connections, and
// every https request hangs until the browser gives up. It reads as a dead
// server and there is nothing in the log to say otherwise.
//
// This is what happened in production behind a proxied dns record, where the
// authority's challenge landed on the proxy and never arrived. The handshake
// has to end.
func TestHandshakeGivesUpOnCertificate(t *testing.T) {
	previous := issueTimeout
	issueTimeout = 50 * time.Millisecond
	defer func() { issueTimeout = previous }()

	a := &autoTLS{domain: "drive.example.com"}
	release := make(chan struct{})
	defer close(release)

	// the authority never answers, which is exactly the failure mode
	stuck := func(*tls.ClientHelloInfo) (*tls.Certificate, error) {
		<-release
		return nil, errors.New("unreachable")
	}

	get := a.certificateFor(stuck, slog.New(slog.DiscardHandler))
	done := make(chan error, 1)
	go func() {
		_, err := get(&tls.ClientHelloInfo{ServerName: a.domain})
		done <- err
	}()

	select {
	case err := <-done:
		if !errors.Is(err, errIssueTimeout) {
			t.Fatalf("wanted the handshake to give up, got %v", err)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("the handshake is still waiting; a request would hang here forever")
	}
}

// A certificate already in the cache has to come back untouched, since that is
// every handshake after the first.
func TestHandshakeReturnsAnIssuedCertificate(t *testing.T) {
	a := &autoTLS{domain: "drive.example.com"}
	want := &tls.Certificate{}
	get := a.certificateFor(func(*tls.ClientHelloInfo) (*tls.Certificate, error) {
		return want, nil
	}, slog.New(slog.DiscardHandler))

	got, err := get(&tls.ClientHelloInfo{ServerName: a.domain})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got != want {
		t.Error("the cached certificate was not the one returned")
	}
}

// Scanners and encrypted-hello probes arrive under names this server was never
// configured for. Refusing them is routine and must not be mistaken for the
// domain's own certificate failing.
func TestUnknownNameIsNotReportedAsFailure(t *testing.T) {
	a := &autoTLS{domain: "drive.example.com"}
	rejected := errors.New("host not configured in HostWhitelist")
	get := a.certificateFor(func(*tls.ClientHelloInfo) (*tls.Certificate, error) {
		return nil, rejected
	}, slog.New(slog.DiscardHandler))

	if _, err := get(&tls.ClientHelloInfo{ServerName: "cloudflare-ech.com"}); !errors.Is(err, rejected) {
		t.Fatalf("wanted the rejection passed through, got %v", err)
	}
	// the throttle is only ever touched for the configured name, so an
	// unrelated name must leave it untouched for the message that matters
	if !a.lastLogged.IsZero() {
		t.Error("another name's rejection was reported as this domain's failure")
	}
}
