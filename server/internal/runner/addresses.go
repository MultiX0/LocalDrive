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
// With a built in certificate the name is https and the machine's own
// addresses are http, on the same port. That is not an inconsistency to tidy
// up: the certificate covers the domain and no authority will ever sign one
// for a lan address, so the port takes either protocol and each address is
// listed with the one that works for it.
func ServerAddresses(domain string, port int, kind TLSKind) []string {
	domain = strings.TrimSpace(domain)

	switch kind {
	case TLSBuiltin:
		out := []string{"https://" + domain}
		if port != 443 {
			out = append(out, fmt.Sprintf("https://%s:%d", domain, port))
			// only the configured port takes both protocols; 443 is https
			// alone. these all work: on this machine's own networks they are
			// served in the clear, and from the internet they redirect to the
			// domain, so nothing is ever sent unencrypted across it.
			out = append(out, LANAddresses(port, false)...)
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
		return "Certificates are requested and renewed automatically, which needs ports\n" +
			"  80 and 443 reachable. The domain is https. An address beside it is\n" +
			"  plain http on your own network, and redirects to the domain from\n" +
			"  anywhere else, because a certificate only ever covers the name."
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
