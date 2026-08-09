package runner

import "testing"

// A share link is the one address that leaves the machine and gets sent to
// somebody else, so it should be the shortest one that actually resolves.
func TestShareLinkDropsThePortOnlyWhenTheBinaryHolds443(t *testing.T) {
	builtin := ProxyConfig{Port: 7443, Domain: "drive.example.com"}
	if got := builtin.BaseURL(); got != "https://drive.example.com" {
		t.Errorf("bare binary: got %q, want no port, since it also binds 443", got)
	}

	// Caddy binds the configured port and nothing else, so dropping the port
	// here would hand somebody a link that does not resolve
	proxied := ProxyConfig{Port: 7443, Domain: "drive.example.com", Proxied: true}
	if got := proxied.BaseURL(); got != "https://drive.example.com:7443" {
		t.Errorf("under caddy: got %q, want the port kept", got)
	}

	on443 := ProxyConfig{Port: 443, Domain: "drive.example.com", Proxied: true}
	if got := on443.BaseURL(); got != "https://drive.example.com" {
		t.Errorf("on 443: got %q, want no redundant port", got)
	}

	if got := (ProxyConfig{Port: 7443}).BaseURL(); got != "" {
		t.Errorf("no domain: got %q, want empty so the app fills it in", got)
	}
}
