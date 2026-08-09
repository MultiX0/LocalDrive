package runner

import (
	"crypto/tls"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/crypto/acme/autocert"

	"github.com/MultiX0/LocalDrive/server/internal/config"
)

// acme talks to Let's Encrypt on these two ports and nowhere else. A server
// answering only on 7443 can never be issued a certificate, whatever it is
// told, so the challenge listeners are separate from the port people use.
const (
	tlsPort    = 443
	acmePort   = 80
	tlsDirName = "certs"
)

// autoTLS is the certificate manager plus the extra listeners it needs.
type autoTLS struct {
	manager *autocert.Manager
	domain  string
}

// wantsAutoTLS reports whether this process should get its own certificate.
//
// Behind Caddy the answer is always no: compose pins LD_TLS=off, because two
// ACME clients asking for the same domain fight over the challenge and both
// lose.
func wantsAutoTLS(cfg *config.Config) bool {
	if cfg.TLSDomain == "" {
		return false
	}
	switch cfg.TLSMode {
	case "off", "false", "0", "none":
		return false
	}
	// an ip address is not a name an authority will sign
	if net.ParseIP(cfg.TLSDomain) != nil {
		return false
	}
	return strings.Contains(cfg.TLSDomain, ".")
}

// maybeAutoTLS returns nil when this server should stay on plain http, which
// is every install without a domain. nil here is the normal case, not an
// error and not a degraded mode.
func maybeAutoTLS(cfg *config.Config) (*autoTLS, error) {
	if !wantsAutoTLS(cfg) {
		return nil, nil
	}
	return newAutoTLS(cfg)
}

// newAutoTLS prepares the certificate manager. Certificates are cached beside
// the database so a restart does not ask for a new one and hit the rate limit.
func newAutoTLS(cfg *config.Config) (*autoTLS, error) {
	dir := filepath.Join(config.DataDirFor(cfg.DBPath), tlsDirName)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, fmt.Errorf("certificate cache %s: %w", dir, err)
	}
	m := &autocert.Manager{
		Prompt:     autocert.AcceptTOS,
		Cache:      autocert.DirCache(dir),
		HostPolicy: autocert.HostWhitelist(cfg.TLSDomain),
		Email:      cfg.TLSEmail,
	}
	return &autoTLS{manager: m, domain: cfg.TLSDomain}, nil
}

// listeners returns every socket the server should answer on.
//
// The certificate is served on 443 and on the configured port both, so the
// address printed at setup keeps working while the domain also answers on the
// port a browser uses by default.
func (a *autoTLS) listeners(addr string, log *slog.Logger) []net.Listener {
	tlsConfig := a.manager.TLSConfig()
	tlsConfig.MinVersion = tls.VersionTLS12

	var out []net.Listener
	seen := map[string]bool{}

	for _, target := range []string{fmt.Sprintf(":%d", tlsPort), addr} {
		port := portOf(target)
		if port == "" || seen[port] {
			continue
		}
		seen[port] = true
		ln, err := tls.Listen("tcp", ":"+port, tlsConfig)
		if err != nil {
			// 443 needs privileges the process may not have. That is worth
			// saying out loud rather than exiting, since the other port may
			// still be serving perfectly well.
			log.Warn("could not listen for https", "port", port, "error", err)
			continue
		}
		log.Info("listening for https", "port", port, "domain", a.domain)
		out = append(out, ln)
	}
	return out
}

// challengeServer answers the ACME http-01 challenge and sends everything else
// to https. Without it a certificate can never be issued in the first place.
func (a *autoTLS) challengeServer(log *slog.Logger) *http.Server {
	redirect := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host := r.Host
		if h, _, err := net.SplitHostPort(host); err == nil {
			host = h
		}
		http.Redirect(w, r, "https://"+host+r.URL.RequestURI(), http.StatusMovedPermanently)
	})
	return &http.Server{
		Addr:              fmt.Sprintf(":%d", acmePort),
		Handler:           a.manager.HTTPHandler(redirect),
		ReadHeaderTimeout: 10 * time.Second,
		ErrorLog:          slog.NewLogLogger(log.Handler(), slog.LevelWarn),
	}
}

func portOf(addr string) string {
	addr = strings.TrimSpace(addr)
	if addr == "" {
		return ""
	}
	if _, port, err := net.SplitHostPort(addr); err == nil {
		return port
	}
	return strings.TrimPrefix(addr, ":")
}
