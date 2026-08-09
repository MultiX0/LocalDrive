package runner

import (
	"fmt"
	"strings"
)

// TLSKind is who holds the certificate. It decides which addresses answer, so
// setup and status both ask this rather than working it out separately and
// drifting apart.
type TLSKind int

const (
	// TLSNone is plain http, which is every install without a domain.
	TLSNone TLSKind = iota
	// TLSProxy is Caddy in front, which only exists under Docker and only
	// binds the configured port.
	TLSProxy
	// TLSBuiltin is the server holding its own certificate, on 443 and on the
	// configured port both.
	TLSBuiltin
)

// TLSKindFor works out how an install serves https.
func TLSKindFor(domain, tlsMode string, docker bool) TLSKind {
	if strings.TrimSpace(domain) == "" {
		return TLSNone
	}
	switch strings.ToLower(strings.TrimSpace(tlsMode)) {
	case "off", "false", "0", "none":
		return TLSNone
	}
	if docker {
		return TLSProxy
	}
	return TLSBuiltin
}

// ServerAddresses is every address that actually answers, most useful first.
//
// The machine's own ip addresses are left out once there is a certificate.
// They still accept a connection, but the certificate covers the domain, so
// hitting an ip warns about the name. Do not list those next to ones that
// work.
func ServerAddresses(domain string, port int, kind TLSKind) []string {
	domain = strings.TrimSpace(domain)

	switch kind {
	case TLSBuiltin:
		out := []string{"https://" + domain}
		if port != 443 {
			out = append(out, fmt.Sprintf("https://%s:%d", domain, port))
		}
		return out

	case TLSProxy:
		// caddy binds the configured port and nothing else
		if port == 443 {
			return []string{"https://" + domain}
		}
		return []string{fmt.Sprintf("https://%s:%d", domain, port)}
	}

	// no certificate, so the name is not the point and every address works
	var out []string
	if domain != "" {
		out = append(out, fmt.Sprintf("http://%s:%d", domain, port))
	}
	return append(out, LANAddresses(port, false)...)
}

// AddressNote is the line printed under the addresses, or empty when there is
// nothing worth saying.
func AddressNote(domain string, kind TLSKind) string {
	switch kind {
	case TLSBuiltin:
		return "Certificates are requested and renewed automatically. Ports 80 and 443\n" +
			"  have to be reachable for that, and this machine's ip addresses will warn\n" +
			"  about the certificate name because it is issued for the domain."
	case TLSProxy:
		return "Caddy holds the certificate and renews it on its own."
	}
	if strings.TrimSpace(domain) != "" {
		return "Plain http, because LD_TLS is off. Put a reverse proxy in front to\n" +
			"  serve https, or remove LD_TLS to let the server hold its own certificate."
	}
	return "Plain http. Set LD_DOMAIN in .env to a domain pointing here and it gets\n" +
		"  a real certificate on its own."
}
