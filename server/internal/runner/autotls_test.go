package runner

import (
	"testing"

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
