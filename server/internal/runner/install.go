package runner

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
)

// Install is where one server's configuration and data live. Everything the
// binary does outside serving is relative to this directory.
type Install struct {
	Dir     string
	EnvPath string
	DataDir string
}

// EnvHome overrides where the binary looks for an install.
const EnvHome = "LOCALDRIVE_HOME"

// FindInstall resolves the install directory, in the order someone would
// expect: an explicit flag, the environment, next to the executable, then the
// platform's own place for application data.
func FindInstall(args []string) (Install, error) {
	dir := ""

	for i, arg := range args {
		if (arg == "--dir" || arg == "-d") && i+1 < len(args) {
			dir = args[i+1]
			break
		}
		if strings.HasPrefix(arg, "--dir=") {
			dir = strings.TrimPrefix(arg, "--dir=")
			break
		}
	}
	if dir == "" {
		dir = strings.TrimSpace(os.Getenv(EnvHome))
	}
	if dir == "" {
		// an install sitting next to the executable is the portable case:
		// unzip it anywhere, run it, and everything stays in that folder
		if exe, err := os.Executable(); err == nil {
			candidate := filepath.Dir(exe)
			if _, statErr := os.Stat(filepath.Join(candidate, ".env")); statErr == nil {
				dir = candidate
			}
		}
	}
	if dir == "" {
		dir = DefaultInstallDir()
	}

	abs, err := filepath.Abs(dir)
	if err != nil {
		return Install{}, err
	}
	return Install{
		Dir:     abs,
		EnvPath: filepath.Join(abs, ".env"),
		DataDir: filepath.Join(abs, "data"),
	}, nil
}

// DefaultInstallDir is the platform's own place for this kind of thing, so a
// person who never picks a folder still gets a sensible one.
func DefaultInstallDir() string {
	if runtime.GOOS == "windows" {
		if base := os.Getenv("LOCALAPPDATA"); base != "" {
			return filepath.Join(base, "LocalDrive")
		}
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, "LocalDrive")
		}
		return "LocalDrive"
	}
	if base := os.Getenv("XDG_DATA_HOME"); base != "" {
		return filepath.Join(base, "localdrive")
	}
	if home, err := os.UserHomeDir(); err == nil {
		return filepath.Join(home, ".local", "share", "localdrive")
	}
	return "/var/lib/localdrive"
}

// Exists reports whether this directory already holds a configured server.
func (i Install) Exists() bool {
	_, err := os.Stat(i.EnvPath)
	return err == nil
}

// ComposePath is where the generated compose file lives.
func (i Install) ComposePath() string {
	return filepath.Join(i.Dir, "docker-compose.yml")
}

// CaddyfilePath is where the generated proxy configuration lives.
func (i Install) CaddyfilePath() string {
	return filepath.Join(i.Dir, "Caddyfile")
}

// HasCompose reports whether this install is the Docker kind.
func (i Install) HasCompose() bool {
	_, err := os.Stat(i.ComposePath())
	return err == nil
}

// LoadEnv reads a .env file into the process environment, without clobbering
// anything already set, so a container's own environment always wins.
func (i Install) LoadEnv() error {
	file, err := os.Open(i.EnvPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, found := strings.Cut(line, "=")
		if !found {
			continue
		}
		key = strings.TrimSpace(key)
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if key == "" {
			continue
		}
		if _, already := os.LookupEnv(key); already {
			continue
		}
		if err := os.Setenv(key, value); err != nil {
			return err
		}
	}
	return scanner.Err()
}

// ReadEnv returns the install's settings as a map, for the commands that need
// to report a port or a data directory back.
func (i Install) ReadEnv() map[string]string {
	out := map[string]string{}
	file, err := os.Open(i.EnvPath)
	if err != nil {
		return out
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if key, value, found := strings.Cut(line, "="); found {
			out[strings.TrimSpace(key)] = strings.Trim(strings.TrimSpace(value), `"'`)
		}
	}
	return out
}

// Port returns the port this install serves on.
func (i Install) Port() int {
	if raw, ok := i.ReadEnv()["LD_PORT"]; ok {
		if port, err := strconv.Atoi(raw); err == nil && port > 0 {
			return port
		}
	}
	return DefaultPort
}

// WriteEnvFile writes the settings file, keys in a stable order so a diff
// between two installs is readable.
func WriteEnvFile(path string, values map[string]string) error {
	order := []string{
		"LD_PORT", "LD_DOMAIN", "LD_TLS_EMAIL",
		"APP_ENV", "LISTEN_ADDR", "LOG_LEVEL", "DATA_DIR",
		"DB_PATH", "LIBRARY_PATH", "EXTERNAL_MOUNTS_PATH",
		"MOUNT_HELPER_SOCKET", "MOUNT_HELPER_SHARED_SECRET",
		"LAN_DISCOVERY_SOCKET", "LAN_DISCOVERY_SHARED_SECRET",
		"JWT_SECRET", "ACCESS_TOKEN_TTL", "REFRESH_TOKEN_TTL",
		"MAX_UPLOAD_CONCURRENCY", "WORKER_POOL_SIZE", "DEFAULT_QUOTA_BYTES",
		"TRASH_RETENTION_DAYS", "VERSION_RETENTION_COUNT", "VERSION_RETENTION_DAYS",
		"ENABLE_LAN_DISCOVERY_DEFAULT", "REQUIRE_DEVICE_APPROVAL_DEFAULT",
		"ALLOW_SELF_REGISTRATION_DEFAULT",
		"PUBLIC_BASE_URL", "CORS_ALLOWED_ORIGINS", "ENCRYPTION_KEY", "METRICS_ENABLED",
	}
	seen := map[string]bool{}
	var b strings.Builder
	b.WriteString("# Local Drive, generated by localdrive setup. Keep this file private.\n")
	for _, key := range order {
		if value, ok := values[key]; ok {
			b.WriteString(key + "=" + value + "\n")
			seen[key] = true
		}
	}
	// anything the caller added that the order above does not know about
	var extra []string
	for key := range values {
		if !seen[key] {
			extra = append(extra, key)
		}
	}
	sort.Strings(extra)
	for _, key := range extra {
		b.WriteString(key + "=" + values[key] + "\n")
	}
	return os.WriteFile(path, []byte(b.String()), 0o600)
}

// maxLANAddresses caps how many are printed. A list is read; a wall is
// skipped, and the useful line is the first one anyway.
const maxLANAddresses = 3

// virtualInterfaces belong to containers and virtual machines rather than to
// reaching this machine. A VPS with four bridges offered eight addresses, six
// of them unreachable.
var virtualInterfaces = []string{
	"docker", "br-", "lxdbr", "lxcbr", "veth", "virbr", "vmnet", "vboxnet",
	"cni", "flannel", "cali", "kube", "podman", "tun", "tap", "utun",
}

// LANAddresses returns every address this machine can be reached at, best
// first. A self-hosted server is usually an address on the local network, not
// a domain, so this is what the setup tool prints and what the app connects to.
func LANAddresses(port int, tls bool) []string {
	scheme := "http"
	if tls {
		scheme = "https"
	}
	var out []string

	interfaces, err := net.Interfaces()
	if err != nil {
		return out
	}
	type candidate struct {
		address string
		rank    int
	}
	var found []candidate

	for _, iface := range interfaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		// a tunnel is a link to one other place, not an address this machine
		// is reached at on a network it belongs to
		if iface.Flags&net.FlagPointToPoint != 0 || isVirtualInterface(iface.Name) {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			ipNet, ok := addr.(*net.IPNet)
			if !ok {
				continue
			}
			ip := ipNet.IP.To4()
			if ip == nil || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
				continue
			}
			// a home network address is the one someone actually wants
			rank := 2
			switch {
			case ip[0] == 192 && ip[1] == 168:
				rank = 0
			case ip[0] == 10:
				rank = 1
			case ip[0] == 172 && ip[1] >= 16 && ip[1] <= 31:
				rank = 1
			}
			found = append(found, candidate{
				address: fmt.Sprintf("%s://%s:%d", scheme, ip.String(), port),
				rank:    rank,
			})
		}
	}
	sort.SliceStable(found, func(a, b int) bool { return found[a].rank < found[b].rank })
	sawLocalNetwork := false
	for _, c := range found {
		if len(out) >= maxLANAddresses {
			break
		}
		if c.rank < 2 {
			sawLocalNetwork = true
		}
		out = append(out, c.address)
	}

	// an mdns name resolves for nobody on a machine whose only address is
	// public, which is what a VPS is
	if sawLocalNetwork {
		if host, err := os.Hostname(); err == nil && host != "" {
			out = append(out, fmt.Sprintf("%s://%s.local:%d", scheme, host, port))
		}
	}
	return out
}

func isVirtualInterface(name string) bool {
	lower := strings.ToLower(name)
	for _, prefix := range virtualInterfaces {
		if strings.HasPrefix(lower, prefix) {
			return true
		}
	}
	return false
}

// PortAvailable reports whether this machine can bind that port right now.
func PortAvailable(port int) bool {
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		return false
	}
	listener.Close()
	return true
}
