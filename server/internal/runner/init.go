package runner

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"

	"github.com/MultiX0/LocalDrive/server/internal/config"
)

// RunInit writes a working configuration without asking anything.
//
// `localdrive setup` is the guided path. This is the one for someone who
// wants to run `docker compose up` themselves and just needs the files to
// exist first, with every secret already generated.
func RunInit(args []string) int {
	install, err := FindInstall(args)
	if err != nil {
		return fail(err)
	}
	if err := os.MkdirAll(filepath.Join(install.DataDir, "db"), 0o750); err != nil {
		return fail(err)
	}

	setupHeader()
	setupStep("Preparing " + install.Dir)

	port := DefaultPort
	if raw := os.Getenv("LD_PORT"); raw != "" {
		if parsed, convErr := strconv.Atoi(raw); convErr == nil && parsed > 0 {
			port = parsed
		}
	}
	proxy := ProxyConfig{Port: port, Domain: os.Getenv("LD_DOMAIN")}

	// the secrets land in their own file beside the database, so .env stays
	// something a person can read and edit without meeting a wall of entropy
	created, err := config.EnsureSecrets(filepath.Join(install.DataDir, "db"))
	if err != nil {
		return fail(err)
	}
	if len(created) > 0 {
		setupOk(fmt.Sprintf("Generated %d secrets, unique to this machine", len(created)))
	} else {
		setupOk("Secrets already present, left alone")
	}

	if !install.Exists() {
		env := defaultEnv(install, proxy)
		if err := WriteEnvFile(install.EnvPath, env); err != nil {
			return fail(err)
		}
		setupOk("Wrote " + install.EnvPath)
	} else {
		setupOk(".env already present, left alone")
	}

	if wrote, err := writeIfAbsent(install.CaddyfilePath(), RenderCaddyfile(proxy)); err != nil {
		return fail(err)
	} else if wrote {
		setupOk("Wrote " + install.CaddyfilePath())
	}
	compose := RenderCompose(proxy, install.DataDir, filepath.Join(install.DataDir, "external"))
	if wrote, err := writeIfAbsent(install.ComposePath(), compose); err != nil {
		return fail(err)
	} else if wrote {
		setupOk("Wrote " + install.ComposePath())
	}

	fmt.Println()
	fmt.Println("  Ready. Start it with either of these:")
	fmt.Println()
	fmt.Println("      localdrive start")
	fmt.Println("      docker compose up -d")
	fmt.Println()
	fmt.Println("  Then open http://<this machine>:" + strconv.Itoa(port))
	fmt.Println()
	return 0
}

// defaultEnv is the configuration a person would have typed, without asking.
func defaultEnv(install Install, proxy ProxyConfig) map[string]string {
	return map[string]string{
		"LD_PORT":      strconv.Itoa(proxy.Port),
		"LD_DOMAIN":    proxy.Domain,
		"LD_TLS_EMAIL": proxy.TLSEmail,
		"APP_ENV":      "production",
		"LOG_LEVEL":    "info",
		// host paths, not container paths. docker-compose.yml pins its own
		// values for all of these, so Docker is unaffected; writing container
		// paths here instead would send a bare `localdrive serve` to /data on
		// the host, which on Windows is the root of C: and on Linux needs root.
		"LISTEN_ADDR":          fmt.Sprintf(":%d", proxy.Port),
		"DATA_DIR":             filepath.ToSlash(install.DataDir),
		"EXTERNAL_MOUNTS_HOST": filepath.ToSlash(filepath.Join(install.DataDir, "external")),
		"DB_PATH":              filepath.ToSlash(filepath.Join(install.DataDir, "db", "localdrive.sqlite")),
		"LIBRARY_PATH":         filepath.ToSlash(filepath.Join(install.DataDir, "library")),
		"EXTERNAL_MOUNTS_PATH": filepath.ToSlash(filepath.Join(install.DataDir, "external")),
		// a Docker arrangement; compose sets them for the container, and
		// without one there is nothing to talk to
		"MOUNT_HELPER_SOCKET":             "",
		"LAN_DISCOVERY_SOCKET":            "",
		"ACCESS_TOKEN_TTL":                "15m",
		"REFRESH_TOKEN_TTL":               "30d",
		"MAX_UPLOAD_CONCURRENCY":          "4",
		"WORKER_POOL_SIZE":                "2",
		"DEFAULT_QUOTA_BYTES":             "0",
		"TRASH_RETENTION_DAYS":            "30",
		"VERSION_RETENTION_COUNT":         "20",
		"VERSION_RETENTION_DAYS":          "180",
		"ENABLE_LAN_DISCOVERY_DEFAULT":    "true",
		"REQUIRE_DEVICE_APPROVAL_DEFAULT": "true",
		"ALLOW_SELF_REGISTRATION_DEFAULT": "false",
		"PUBLIC_BASE_URL":                 proxy.BaseURL(),
	}
}
