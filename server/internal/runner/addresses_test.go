package runner

import (
	"strings"
	"testing"
)

func TestTLSKindFor(t *testing.T) {
	cases := []struct {
		name   string
		domain string
		mode   string
		docker bool
		want   TLSKind
	}{
		{"no domain, direct", "", "", false, TLSNone},
		{"no domain, docker", "", "", true, TLSNone},
		{"domain, direct", "drive.example.com", "", false, TLSBuiltin},
		{"domain, docker", "drive.example.com", "", true, TLSProxy},
		{"domain, direct, turned off", "drive.example.com", "off", false, TLSNone},
		{"domain, docker, pinned off", "drive.example.com", "off", true, TLSNone},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := TLSKindFor(tc.domain, tc.mode, tc.docker); got != tc.want {
				t.Fatalf("TLSKindFor(%q, %q, docker=%v) = %v, want %v",
					tc.domain, tc.mode, tc.docker, got, tc.want)
			}
		})
	}
}

// A domain with the built in certificate answers on 443 and on the configured
// port. The machine's own ip addresses are left out on purpose: they connect,
// then fail the certificate name check, so listing them sends people to a
// warning page.
func TestAddressesForADomainOnTheBareBinary(t *testing.T) {
	got := ServerAddresses("drive.example.com", 7443, TLSBuiltin)
	want := []string{"https://drive.example.com", "https://drive.example.com:7443"}
	assertAddresses(t, got, want)

	for _, a := range got {
		if strings.HasPrefix(a, "http://") {
			t.Fatalf("%q is plain http, but a certificate is being served", a)
		}
	}
}

func TestPort443DropsTheRedundantPort(t *testing.T) {
	got := ServerAddresses("drive.example.com", 443, TLSBuiltin)
	assertAddresses(t, got, []string{"https://drive.example.com"})
}

// Caddy binds the configured port only, so 443 is not a second way in.
func TestAddressesUnderDocker(t *testing.T) {
	got := ServerAddresses("drive.example.com", 7443, TLSProxy)
	assertAddresses(t, got, []string{"https://drive.example.com:7443"})
}

// With no certificate every address is equally valid, and none of them should
// claim https.
func TestAddressesWithNoDomainStayPlain(t *testing.T) {
	for _, a := range ServerAddresses("", 7443, TLSNone) {
		if strings.HasPrefix(a, "https://") {
			t.Fatalf("%q claims https on a server with no certificate", a)
		}
	}
}

func TestNoteNeverTellsYouToSetSomethingAlreadySet(t *testing.T) {
	note := AddressNote("drive.example.com", TLSBuiltin)
	if strings.Contains(note, "Set LD_DOMAIN") {
		t.Fatalf("the note tells someone with a domain to set LD_DOMAIN: %q", note)
	}
	if strings.Contains(note, "Caddy") {
		t.Fatalf("the note credits Caddy for a certificate the binary holds: %q", note)
	}
	if empty := AddressNote("", TLSNone); !strings.Contains(empty, "LD_DOMAIN") {
		t.Fatalf("an install with no domain should be told how to get https: %q", empty)
	}
}

func assertAddresses(t *testing.T, got, want []string) {
	t.Helper()
	if len(got) != len(want) {
		t.Fatalf("got %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("got %v, want %v", got, want)
		}
	}
}
