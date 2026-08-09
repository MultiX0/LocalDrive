package runner

import (
	"crypto/tls"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
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
	// port is the configured port, the one that answers both protocols. It is
	// where anything arriving in the clear gets pointed.
	port int
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
	port, _ := strconv.Atoi(portOf(cfg.Addr))
	return &autoTLS{manager: m, domain: cfg.TLSDomain, port: port}, nil
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

		// 443 is https by definition and every client assumes so, which makes
		// it the wrong place to guess. The configured port is the one someone
		// reaches by ip from the same network, where no certificate can ever
		// help them, so that is the one that answers either protocol.
		var (
			ln  net.Listener
			err error
		)
		if port == strconv.Itoa(tlsPort) {
			ln, err = tls.Listen("tcp", ":"+port, tlsConfig)
		} else {
			ln, err = listenBothProtocols("tcp", ":"+port, tlsConfig)
		}
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

// guard decides what to do with a request that arrives in the clear on the
// port that accepts both protocols.
//
// Requests over https go straight through, which is nearly all of them. For
// the rest the question is whether https was available and went unused:
//
//   - Under the domain it was, since that is the name on the certificate, so
//     the request is redirected and never reaches the application in the clear.
//   - From an address on a private network it was not, and never will be,
//     because no authority signs a certificate for a lan address. Serving it is
//     the point of this whole listener: it is a phone on the same wifi as the
//     server, and refusing it would mean setting a domain silently removes
//     local access.
//   - Anything else in the clear is coming over the public internet to an
//     address rather than a name. The name works for them, so send them to it
//     rather than carrying their password across the internet in plain text.
func (a *autoTLS) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.TLS != nil {
			next.ServeHTTP(w, r)
			return
		}
		if fromPrivateNetwork(r.RemoteAddr) && !sameHost(r.Host, a.domain) {
			next.ServeHTTP(w, r)
			return
		}

		// keep the port they arrived on: 443 may not have been bindable, and
		// sending them to a port with nothing on it is worse than not
		// redirecting at all
		target := "https://" + a.domain
		if port := localPort(r); port != "" && port != strconv.Itoa(tlsPort) {
			target += ":" + port
		}
		http.Redirect(w, r, target+r.URL.RequestURI(), http.StatusMovedPermanently)
	})
}

// fromPrivateNetwork reports whether a request came from the same network
// rather than across the internet.
func fromPrivateNetwork(remoteAddr string) bool {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		host = remoteAddr
	}
	ip := net.ParseIP(strings.Trim(host, "[]"))
	if ip == nil {
		return false
	}
	return ip.IsLoopback() || ip.IsPrivate() ||
		ip.IsLinkLocalUnicast() || ip.IsUnspecified()
}

// sameHost reports whether a request was addressed to the name on the
// certificate, port and letter case aside.
func sameHost(requestHost, domain string) bool {
	return strings.EqualFold(hostOnly(requestHost), strings.TrimSpace(domain))
}

func hostOnly(hostport string) string {
	hostport = strings.TrimSpace(hostport)
	if host, _, err := net.SplitHostPort(hostport); err == nil {
		return host
	}
	return hostport
}

// localPort is the port the request actually arrived on, which is not always
// the one in the configuration.
func localPort(r *http.Request) string {
	addr, ok := r.Context().Value(http.LocalAddrContextKey).(net.Addr)
	if !ok {
		return ""
	}
	_, port, err := net.SplitHostPort(addr.String())
	if err != nil {
		return ""
	}
	return port
}

// challengeServer answers the ACME http-01 challenge and sends everything else
// to https. Without it a certificate can never be issued in the first place.
func (a *autoTLS) challengeServer(log *slog.Logger) *http.Server {
	redirect := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Someone on the same network typing the machine's address gets port 80
		// before anything else. Sending them to https at that address hands
		// them a certificate error, because the certificate is for the domain,
		// so point them at the port that answers them in the clear instead.
		if a.port != 0 && a.port != tlsPort &&
			fromPrivateNetwork(r.RemoteAddr) && !sameHost(r.Host, a.domain) {
			local := fmt.Sprintf("http://%s:%d%s", hostOnly(r.Host), a.port, r.URL.RequestURI())
			http.Redirect(w, r, local, http.StatusFound)
			return
		}
		// everything else goes to the name, which is the only thing the
		// certificate covers
		http.Redirect(w, r, "https://"+a.domain+r.URL.RequestURI(), http.StatusMovedPermanently)
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
