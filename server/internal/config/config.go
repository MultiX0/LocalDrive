// Package config loads and validates every environment variable the server
// needs, once, at process start. Nothing security-relevant gets a silent
// default.
package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Config is the fully validated runtime configuration.
type Config struct {
	Env    string // dev | production
	Addr   string
	DBPath string

	LibraryPath        string
	ExternalMountsPath string

	MountHelperSocket       string
	MountHelperSharedSecret string
	LANDiscoverySocket      string
	LANDiscoverySecret      string

	JWTSecret       []byte
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration

	MaxUploadConcurrency int
	WorkerPoolSize       int
	DefaultQuotaBytes    int64
	MaxReadConns         int

	CORSAllowedOrigins []string
	EncryptionKey      []byte

	PublicBaseURL string

	// seeds for the server_settings row, only used on first start
	EnableLANDiscoveryDefault    bool
	RequireDeviceApprovalDefault bool
	AllowSelfRegistrationDefault bool

	TrashRetentionDays    int
	VersionRetentionCount int
	VersionRetentionDays  int

	Argon2Memory  uint32
	Argon2Time    uint32
	Argon2Threads uint8

	MetricsEnabled bool
	LogLevel       string

	// which secrets this start had to create, so startup can say so once
	GeneratedSecrets []string
}

// Errors collects every problem found so a misconfigured deploy sees all of
// them at once instead of one per restart.
type Errors []string

func (e Errors) Error() string {
	return "invalid configuration:\n  - " + strings.Join(e, "\n  - ")
}

type loader struct {
	problems Errors
}

// Load reads the environment and returns a validated Config.
func Load() (*Config, error) {
	l := &loader{}
	c := &Config{}

	c.Env = l.str("APP_ENV", "production")
	if c.Env != "dev" && c.Env != "production" {
		l.fail("APP_ENV must be dev or production, got %q", c.Env)
	}
	// 7443 is the port every guide, the app's own default and the QR code all
	// assume. It used to default to 8080, which is the port the server listens
	// on inside the container with Caddy in front of it; compose sets that
	// explicitly now, so the default belongs to the case with nothing in front.
	c.Addr = l.str("LISTEN_ADDR", ":7443")
	c.LogLevel = l.str("LOG_LEVEL", "info")

	dataDir := l.str("DATA_DIR", defaultDataDir())
	c.DBPath = l.path("DB_PATH", filepath.Join(dataDir, "db", "localdrive.sqlite"), true)
	c.LibraryPath = l.path("LIBRARY_PATH", filepath.Join(dataDir, "library"), true)
	c.ExternalMountsPath = l.path("EXTERNAL_MOUNTS_PATH", filepath.Join(dataDir, "external"), true)

	// anything the operator did not set is generated and written down beside
	// the database, so a fresh start needs no hand-made cryptographic material
	generated, secretErr := EnsureSecrets(DataDirFor(c.DBPath))
	if secretErr != nil {
		l.fail("could not prepare the server secrets: %v", secretErr)
	}
	c.GeneratedSecrets = generated

	c.MountHelperSocket = l.str("MOUNT_HELPER_SOCKET", "")
	c.MountHelperSharedSecret = l.str("MOUNT_HELPER_SHARED_SECRET", "")
	if c.MountHelperSocket != "" && len(c.MountHelperSharedSecret) < 16 {
		l.fail("MOUNT_HELPER_SHARED_SECRET must be at least 16 characters when MOUNT_HELPER_SOCKET is set")
	}
	c.LANDiscoverySocket = l.str("LAN_DISCOVERY_SOCKET", "")
	c.LANDiscoverySecret = l.str("LAN_DISCOVERY_SHARED_SECRET", "")
	if c.LANDiscoverySocket != "" && len(c.LANDiscoverySecret) < 16 {
		l.fail("LAN_DISCOVERY_SHARED_SECRET must be at least 16 characters when LAN_DISCOVERY_SOCKET is set")
	}

	secret := l.str("JWT_SECRET", "")
	switch {
	case secret == "":
		l.fail("JWT_SECRET could not be read or generated")
	case len(secret) < 32:
		l.fail("JWT_SECRET must be at least 32 characters, got %d", len(secret))
	case isPlaceholder(secret):
		l.fail("JWT_SECRET is still set to a placeholder value")
	default:
		c.JWTSecret = []byte(secret)
	}

	c.AccessTokenTTL = l.duration("ACCESS_TOKEN_TTL", 15*time.Minute)
	if c.AccessTokenTTL < time.Minute || c.AccessTokenTTL > 24*time.Hour {
		l.fail("ACCESS_TOKEN_TTL must be between 1m and 24h")
	}
	c.RefreshTokenTTL = l.duration("REFRESH_TOKEN_TTL", 30*24*time.Hour)
	if c.RefreshTokenTTL < time.Hour {
		l.fail("REFRESH_TOKEN_TTL must be at least 1h")
	}

	c.MaxUploadConcurrency = l.intRange("MAX_UPLOAD_CONCURRENCY", 4, 1, 64)
	c.WorkerPoolSize = l.intRange("WORKER_POOL_SIZE", 2, 1, 32)
	c.MaxReadConns = l.intRange("MAX_READ_CONNS", 4, 1, 64)
	c.DefaultQuotaBytes = l.int64("DEFAULT_QUOTA_BYTES", 10*1024*1024*1024)
	if c.DefaultQuotaBytes < 0 {
		l.fail("DEFAULT_QUOTA_BYTES must be zero (unlimited) or positive")
	}

	c.TrashRetentionDays = l.intRange("TRASH_RETENTION_DAYS", 30, 1, 3650)
	c.VersionRetentionCount = l.intRange("VERSION_RETENTION_COUNT", 20, 1, 1000)
	c.VersionRetentionDays = l.intRange("VERSION_RETENTION_DAYS", 180, 1, 3650)

	c.Argon2Memory = uint32(l.intRange("ARGON2_MEMORY_KIB", 65536, 8192, 1048576))
	c.Argon2Time = uint32(l.intRange("ARGON2_TIME", 2, 1, 16))
	c.Argon2Threads = uint8(l.intRange("ARGON2_THREADS", 2, 1, 16))

	origins := l.str("CORS_ALLOWED_ORIGINS", "")
	for _, o := range strings.Split(origins, ",") {
		o = strings.TrimSpace(o)
		if o == "" {
			continue
		}
		if o == "*" {
			l.fail("CORS_ALLOWED_ORIGINS may not be a wildcard, list the exact origins")
			continue
		}
		if !strings.HasPrefix(o, "http://") && !strings.HasPrefix(o, "https://") {
			l.fail("CORS_ALLOWED_ORIGINS entry %q must include a scheme", o)
			continue
		}
		c.CORSAllowedOrigins = append(c.CORSAllowedOrigins, strings.TrimSuffix(o, "/"))
	}

	if key := l.str("ENCRYPTION_KEY", ""); key != "" {
		if len(key) < 32 {
			l.fail("ENCRYPTION_KEY must be at least 32 characters when set")
		} else {
			c.EncryptionKey = []byte(key)
		}
	}

	c.PublicBaseURL = strings.TrimSuffix(l.str("PUBLIC_BASE_URL", ""), "/")

	c.EnableLANDiscoveryDefault = l.boolean("ENABLE_LAN_DISCOVERY_DEFAULT", true)
	c.RequireDeviceApprovalDefault = l.boolean("REQUIRE_DEVICE_APPROVAL_DEFAULT", true)
	c.AllowSelfRegistrationDefault = l.boolean("ALLOW_SELF_REGISTRATION_DEFAULT", false)
	c.MetricsEnabled = l.boolean("METRICS_ENABLED", false)

	if len(l.problems) > 0 {
		return nil, l.problems
	}
	return c, nil
}

// Redacted returns a copy safe to log.
func (c *Config) Redacted() map[string]any {
	return map[string]any{
		"env":                    c.Env,
		"addr":                   c.Addr,
		"db_path":                c.DBPath,
		"library_path":           c.LibraryPath,
		"external_mounts_path":   c.ExternalMountsPath,
		"mount_helper_socket":    c.MountHelperSocket,
		"lan_discovery_socket":   c.LANDiscoverySocket,
		"access_token_ttl":       c.AccessTokenTTL.String(),
		"refresh_token_ttl":      c.RefreshTokenTTL.String(),
		"max_upload_concurrency": c.MaxUploadConcurrency,
		"worker_pool_size":       c.WorkerPoolSize,
		"cors_allowed_origins":   c.CORSAllowedOrigins,
		"encryption_enabled":     len(c.EncryptionKey) > 0,
		"metrics_enabled":        c.MetricsEnabled,
	}
}

func (l *loader) fail(format string, args ...any) {
	l.problems = append(l.problems, fmt.Sprintf(format, args...))
}

func (l *loader) str(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return strings.TrimSpace(v)
	}
	return def
}

// defaultDataDir is where data goes when nothing in the environment says.
//
// It used to be /data unconditionally, which is right inside the container and
// wrong everywhere else: on a Linux host /data is at the root of the
// filesystem and needs root to create, and on Windows it lands at the root of
// the system drive. A server started with no .env has to put its database
// somewhere it can actually write.
func defaultDataDir() string {
	// the same variable the CLI uses to locate an install, so a service unit
	// setting it gets a matching database without also spelling out DB_PATH
	if home := strings.TrimSpace(os.Getenv("LOCALDRIVE_HOME")); home != "" {
		return filepath.Join(home, "data")
	}
	if inContainer() {
		return "/data"
	}
	// otherwise beside the binary, which is where init puts it
	if exe, err := os.Executable(); err == nil {
		if resolved, err := filepath.EvalSymlinks(exe); err == nil {
			exe = resolved
		}
		return filepath.Join(filepath.Dir(exe), "data")
	}
	return "data"
}

func inContainer() bool {
	_, err := os.Stat("/.dockerenv")
	return err == nil
}

func (l *loader) path(key, def string, required bool) string {
	v := l.str(key, def)
	if v == "" {
		if required {
			l.fail("%s is required", key)
		}
		return ""
	}
	abs, err := filepath.Abs(v)
	if err != nil {
		l.fail("%s is not a usable path: %v", key, err)
		return v
	}
	return abs
}

func (l *loader) duration(key string, def time.Duration) time.Duration {
	raw := l.str(key, "")
	if raw == "" {
		return def
	}
	d, err := ParseDurationDays(raw)
	if err != nil {
		l.fail("%s must be a duration like 15m, 24h, or 30d, got %q", key, raw)
		return def
	}
	if d <= 0 {
		l.fail("%s must be positive", key)
		return def
	}
	return d
}

func (l *loader) intRange(key string, def, min, max int) int {
	raw := l.str(key, "")
	if raw == "" {
		return def
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		l.fail("%s must be a whole number, got %q", key, raw)
		return def
	}
	if n < min || n > max {
		l.fail("%s must be between %d and %d, got %d", key, min, max, n)
		return def
	}
	return n
}

func (l *loader) int64(key string, def int64) int64 {
	raw := l.str(key, "")
	if raw == "" {
		return def
	}
	n, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		l.fail("%s must be a whole number, got %q", key, raw)
		return def
	}
	return n
}

func (l *loader) boolean(key string, def bool) bool {
	raw := l.str(key, "")
	if raw == "" {
		return def
	}
	b, err := strconv.ParseBool(raw)
	if err != nil {
		l.fail("%s must be true or false, got %q", key, raw)
		return def
	}
	return b
}

func isPlaceholder(v string) bool {
	lower := strings.ToLower(v)
	for _, bad := range []string{"changeme", "placeholder", "your-secret", "secret-here", "xxxxxxxx"} {
		if strings.Contains(lower, bad) {
			return true
		}
	}
	return false
}

// ParseDurationDays accepts a plain day suffix on top of time.ParseDuration,
// so REFRESH_TOKEN_TTL=30d in .env.example works as written.
func ParseDurationDays(raw string) (time.Duration, error) {
	raw = strings.TrimSpace(raw)
	if strings.HasSuffix(raw, "d") {
		n, err := strconv.Atoi(strings.TrimSuffix(raw, "d"))
		if err != nil {
			return 0, errors.New("invalid day duration")
		}
		return time.Duration(n) * 24 * time.Hour, nil
	}
	return time.ParseDuration(raw)
}
