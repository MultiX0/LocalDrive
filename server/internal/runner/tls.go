package runner

import "crypto/tls"

// insecureLocalTLS is used only for the loopback readiness checks during
// setup, before Caddy has finished getting a real certificate. Nothing outside
// this file talks to the server over TLS.
func insecureLocalTLS() *tls.Config {
	return &tls.Config{InsecureSkipVerify: true} // #nosec G402 -- localhost only, during setup
}
