package runner

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/MultiX0/LocalDrive/server/internal/config"
)

// sharedSecret returns a helper's secret from the environment, or from the
// file the server generated for itself when nothing was configured.
//
// This is what lets `docker compose up` work on a fresh clone with no .env at
// all: the server writes the secrets on first start, and the two helpers read
// the same file, mounted read only.
func sharedSecret(envKey string) string {
	if value := strings.TrimSpace(os.Getenv(envKey)); value != "" {
		return value
	}

	dataDir := strings.TrimSpace(os.Getenv("LD_SECRETS_DIR"))
	if dataDir == "" {
		dataDir = config.DataDirFor(
			envOrDefault("DB_PATH", "/data/db/localdrive.sqlite"),
		)
	}

	data, err := os.ReadFile(filepath.Join(dataDir, config.SecretsFileName))
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, found := strings.Cut(line, "=")
		if found && strings.TrimSpace(key) == envKey {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func envOrDefault(key, def string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return def
}
